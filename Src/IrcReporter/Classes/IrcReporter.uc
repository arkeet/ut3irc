/*
   Copyright (C) 2008 Adrian Keet.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this program; if not, write to the Free Software Foundation, Inc.,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.  */

//-----------------------------------------------------------
// $Id$
//-----------------------------------------------------------
class IrcReporter extends IrcClient
    dependson(ReporterChannelConfig)
    config(IrcReporter);

var config string Server;
var config int ServerPort;
var config string CommandPrefix;
var config array<string> AdminHostmasks;
var config array<string> IgnoreHostmasks;
var config array<string> ConnectCommands;

var localized string RunOverString, SpiderMineString, ScorpionKamikazeString, ViperKamikazeString, TelefragString;

var class<GameRules> GameRulesClass;
var GameRules GameRules;

var class<IrcSpectator> ReporterSpectatorClass;
var IrcSpectator ReporterSpectator;

var name LastGameInfoState;
var Actor LastLeader;

var string GameEndReason;

struct PlayerInfo
{
    var PlayerReplicationInfo PRI;
    var Controller Controller;
    var string PlayerName;
    var int Team;
    var int Score;
};

struct PlayerList
{
    var array<PlayerInfo> Entries;
};

var array<PlayerInfo> Players;

struct ReporterCommand
{
    var string CommandName;
    var delegate<ReporterCommandDelegate> Handler;
    var string Usage;
    var string Description;
    var bool bHidden;
};
var array<ReporterCommand> Commands;

var array<ReporterChannelConfig> ChannelConfigs;

delegate ReporterCommandDelegate(string Host, string Target, string Arg);

function RegisterCommand(delegate<ReporterCommandDelegate> Handler, string CommandName,
    string Usage, string Description, optional bool bHiddenCmd = false)
{
    local ReporterCommand C;

    C.CommandName = CommandName;
    C.Handler = Handler;
    C.Usage = Usage;
    C.Description = Description;
    C.bHidden = bHiddenCmd;
    Commands.AddItem(C);
}

function UnregisterCommand(string CommandName)
{
    local int i;

    for (i = 0; i < Commands.Length; ++i)
    {
        if (Commands[i].CommandName ~= CommandName)
        {
            Commands.Remove(i--, 1);
        }
    }
}

function ReporterChannelConfig GetChannelConfig(string Channel)
{
    local ReporterChannelConfig Conf;

    foreach ChannelConfigs(Conf)
    {
        if (Conf.Channel ~= Channel)
            return Conf;
    }
    return none;
}

simulated function PostBeginPlay()
{
    local array<string> Chans;
    local string C;
    local ReporterChannelConfig Conf;

    super.PostBeginPlay();

    ReporterSpectator = Spawn(ReporterSpectatorClass);
    ReporterSpectator.Reporter = self;

    GetPerObjectConfigSections(class'ReporterChannelConfig', Chans);
    foreach Chans(C)
    {
        Split2(" ", C, C); // for some reason it gives us stuff like "#channel ReporterChannelConfig"
        Conf = new(none, C) class'ReporterChannelConfig';
        Conf.Channel = C;
        ChannelConfigs.AddItem(Conf);
    }

    RegisterHandler(IrcReporter_Handler_JOIN, "JOIN");
    RegisterHandler(IrcReporter_Handler_PRIVMSG, "PRIVMSG");

    RegisterCommand(Command_commands, "commands",
        "commands", "Lists the available commands.");
    RegisterCommand(Command_help, "help",
        "help <command>", "Gives more information about a command.");
    RegisterCommand(Command_players, "players",
        "players", "Lists the players on the server.");
    RegisterCommand(Command_scores, "scores",
        "scores", "Gives a detailed score report.");
    RegisterCommand(Command_status, "status",
        "status", "Gives some brief information about the current game.");
    RegisterCommand(Command_say, "say",
        "say <text>", "Relays a message to the game.");
    RegisterCommand(Command_raw, "raw",
        "raw <message>", "Admins only - sends a raw IRC message.");
    RegisterCommand(Command_admin, "admin",
        "admin <command>", "Admins only - runs an admin command on the UT3 server.");
    RegisterCommand(Command_topicformat, "topicformat",
        "topicformat [<format>]", "Gets or sets the topic format.");
    RegisterCommand(Command_motd, "motd",
        "motd [<text>]", "Gets or sets the message of the day.");
    RegisterCommand(Command_ignore, "ignore",
        "ignore <hostmask>", "Adds a hostmask to the ignore list.");
    RegisterCommand(Command_unignore, "unignore",
        "unignore <hostmask>", "Removes a hostmask from the ignore list.");
    RegisterCommand(Command_ignorelist, "ignorelist",
        "ignorelist", "Lists the hostmasks being ignored.");
    RegisterCommand(Command_wut, "wut",
        "wut", "Wut?", true);

    Connect(Server, ServerPort);

    WorldInfo.Game.AddGameRules(GameRulesClass);
}

simulated function Tick(float DeltaTime)
{
    super.Tick(DeltaTime);
    UpdatePlayers();
    CheckGameStatus();
}

event Destroyed()
{
    ReporterSpectator.Destroy();

    // Does this even happen?
    QUIT("Bye");
}

function Registered()
{
    local string Cmd;
    local ReporterChannelConfig Conf;

    super.Registered();

    foreach ConnectCommands(Cmd)
    {
        Cmd = Repl(Cmd, "%n", CurrentNick);
        SendLine(Cmd);
    }
    foreach ChannelConfigs(Conf)
    {
        JOIN(Conf.Channel);
    }
}

function string FormatTime(int Time)
{
    return class'UTHUD'.static.FormatTime(Time);
}

function string GetTimestamp()
{
    local string Str;

    if (WorldInfo.Game.GetStateName() == 'MatchInProgress')
    {
        if (WorldInfo.GRI.TimeLimit != 0)
        {
            if (WorldInfo.Game.bOverTime)
                Str = "Overtime";
            else
                Str = FormatTime(WorldInfo.GRI.RemainingTime);
        }
        else
        {
            Str = FormatTime(WorldInfo.GRI.ElapsedTime);
        }
        return IrcColor("[" $ Str $ "]", IrcLtGrey) $ " ";
    }
    else
    {
        return "";
    }
}

function ChannelMessage(string Channel, string Text, optional bool bTimestamp = true)
{
    local IrcChannel C;

    C = GetChannel(Channel);
    if (C != none)
    {
        if (bTimestamp)
            Text = GetTimestamp() $ Text;
        C.SendMessage(Text);
    }
    else
    {
        Log("Tried to send a message to" @ Channel @ "while not in the channel!", LL_Warning);
    }
}

function ReporterMessage(string Text, name MessageType, optional bool bTimestamp = true)
{
    local ReporterChannelConfig Conf;

    foreach ChannelConfigs(Conf)
    {
        if (ShowMessage(Conf, MessageType))
            ChannelMessage(Conf.Channel, Text, bTimestamp);
    }
}

function ChannelTopic(string Channel, string Text)
{
    local IrcChannel C;

    C = GetChannel(Channel);
    if (C != none)
    {
        C.SetTopic(Text);
    }
    else
    {
        Log("Tried to set the topic of" @ Channel @ "while not in the channel!", LL_Warning);
    }
}

function string StringRepeat(string Str, int Times)
{
    local string Result;

    while (Times-- > 0)
        Result $= Str;
    return Result;
}

function int GetTeamIdx(PlayerReplicationInfo PRI)
{
    if (PRI.bOnlySpectator)
        return -2;
    if (PRI.Team != none)
        return PRI.GetTeamNum();
    return -1;
}

function string GetTeamName(int Team, optional bool bShort)
{
    if (bShort)
    {
        switch (Team)
        {
            case 0:
                return "Red";
            case 1:
                return "Blue";
            case 2:
                return "Green";
            case 3:
                return "Gold";
        }
    }
    else
    {
        switch (Team)
        {
            case 0:
                return "Red Team";
            case 1:
                return "Blue Team";
            case 2:
                return "Green Team";
            case 3:
                return "Gold Team";
            case -1:
                return "No Team";
            case -2:
                return "Spectators";
        }
    }
    return "";
}

function int GetTeamIrcColor(int Team)
{
    switch (Team)
    {
        case 0:
            return IrcRed;
        case 1:
            return IrcBlue;
        case 2:
            return IrcGreen;
        case 3:
            return IrcOrange;
        case -1:
            return IrcGreen;
        case -2:
            return IrcPurple;
        default:
            return IrcBlack;
    }
}

function string FormatPlayerName(PlayerReplicationInfo PRI, optional coerce string Text, optional int TeamIdx = 255)
{
    if (Text == "")
        Text = PRI.GetPlayerAlias();
    return IrcBold(IrcColor(Text, GetTeamIrcColor(
        TeamIdx == 255 ? GetTeamIdx(PRI) : TeamIdx)));
}

function string FormatTeamName(int Team, optional coerce string Text, optional bool bShort)
{
    if (Text == "")
        Text = GetTeamName(Team, bShort);
    return IrcBold(IrcColor(Text, GetTeamIrcColor(Team)));
}

function string FormatScoreListEntry(string ScoreName, int Score, int Team, int Width)
{
    local string LeftPart, RightPart, Ret;

    LeftPart = ScoreName;
    RightPart = string(Score);

    if (Len(LeftPart) + Len(RightPart) >= Width)
        return Left(LeftPart, Width - Len(RightPart));
    else
    {
        Ret = LeftPart $ StringRepeat(" ", Width - Len(LeftPart) - Len(RightPart)) $ RightPart;
        Ret = IrcColor(Ret, GetTeamIrcColor(Team));
        return Ret;
    }
}

function string GameStatus()
{
    return "Current game:" @ IrcBold(WorldInfo.Game.GameName)
        @ "on" @ IrcBold(WorldInfo.GetMapName());
}

function string ShortTeamScores()
{
    return "Current score:"
        @ FormatTeamName(0, int(UTTeamGame(WorldInfo.Game).Teams[0].Score))
        @ "-"
        @ FormatTeamName(1, int(UTTeamGame(WorldInfo.Game).Teams[1].Score));
}

const ColWidth = 24;

function string LongTeamScores()
{
    local string Str;
    local int i;
    local TeamInfo Team;

    if (UTTeamGame(WorldInfo.Game) != none)
    {
        Str = "Scores: [ ";
        for (i = 0; i < 2; ++i)
        {
            Team = UTTeamGame(WorldInfo.Game).Teams[i];
            if (i > 0)
                Str $= " | ";
            Str $= IrcBold(FormatScoreListEntry(GetTeamName(i), Team.Score, i, ColWidth));
        }
        Str $= " ]";
    }
    return Str;
}

function array<string> PlayerScores()
{
    local array<PlayerReplicationInfo> PRIArray;
    local PlayerReplicationInfo PRI;
    local array<PlayerList> PlayerLists;
    local int i, j;
    local PlayerList L;
    local PlayerInfo Player;
    local int MaxPlayerListLen;
    local string Str;

    local array<string> Result;

    MaxPlayerListLen = 0;

    WorldInfo.GRI.SortPRIArray();
    WorldInfo.GRI.GetPRIArray(PRIArray);
    foreach PRIArray(PRI)
    {
        if (PRI.bOnlySpectator)
            continue;

        Player.PRI = PRI;
        Player.PlayerName = PRI.GetPlayerAlias();
        Player.Team = GetTeamIdx(PRI);
        Player.Score = int(PRI.Score);

        i = Player.Team;
        if (i < -1)
            continue;
        if (i == -1)
            i = 0;
        if (PlayerLists.Length <= i + 1)
            PlayerLists.Length = i + 1;

        PlayerLists[i].Entries.AddItem(Player);
        MaxPlayerListLen = Max(PlayerLists[i].Entries.Length, MaxPlayerListLen);
    }

    for (i = 0; i < MaxPlayerListLen; ++i)
    {
        Str = "Scores: [ ";
        foreach PlayerLists(L, j)
        {
            if (j > 0)
                Str $= " | ";
            if (i < L.Entries.Length)
            {
                Player = L.Entries[i];
                Str $= FormatScoreListEntry(Player.PlayerName, Player.Score, Player.Team, ColWidth);
            }
            else
            {
                Str $= StringRepeat(" ", ColWidth);
            }
        }
        Str $= " ]";
        Result.AddItem(Str);
    }

    return Result;
}

function UpdateReporterTopic()
{
    local ReporterChannelConfig Conf;
    local string NewTopic;

    foreach ChannelConfigs(Conf)
    {
        if (!Conf.bSetTopic)
            continue;

        NewTopic = Conf.TopicFormat;
        NewTopic = Repl(NewTopic, "%motd", Conf.Motd);
        NewTopic = Repl(NewTopic, "%gametype", WorldInfo.Game.GameName);
        NewTopic = Repl(NewTopic, "%map", WorldInfo.GetMapName());
        NewTopic = Repl(NewTopic, "%numplayers", WorldInfo.Game.GetNumPlayers());
        NewTopic = Repl(NewTopic, "%maxplayers", WorldInfo.Game.MaxPlayers);

        ChannelTopic(Conf.Channel, NewTopic);
    }
}

function TeamMessage(PlayerReplicationInfo PRI, coerce string S, name Type, optional float MsgLifeTime)
{
    if (Type == 'Say')
    {
        ReporterMessage(FormatPlayerName(PRI, PRI.GetPlayerAlias() $ ":") @ S, 'Chat', false);
    }
}

function bool ShowMessage(ReporterChannelConfig Conf, name MessageType)
{
    local MessageFilter F;

    foreach Conf.MessageTypes(F)
    {
        if (F.MessageType == MessageType)
            return F.bShow;
    }
    return (MessageType != 'Misc');
}

function ThrottleDropEvent()
{
    ReporterMessage("I had to drop some messages to catch up.", 'Throttle');
}

function ReceiveLocalizedMessage(class<LocalMessage> Message, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
    local string PRI1Name, PRI2Name;
    local string Str;
    local class<UTDamageType> DT;

    PRI1Name = RelatedPri_1 != none ? FormatPlayerName(RelatedPRI_1) : "someone";
    PRI2Name = RelatedPri_2 != none ? FormatPlayerName(RelatedPRI_2) : "someone";

    Log(self @ "ReceiveLocalizedMessage" @ Message @ switch @
        RelatedPRI_1 @ RelatedPRI_2 @ OptionalObject, LL_Debug);

    if (ClassIsChildOf(Message, class'UTStartupMessage'))
    {
        if (Switch == 5)
            ReporterMessage("The match has begun!", 'Startup');
    }
    else if (ClassIsChildOf(Message, class'UTDeathMessage'))
    {
        Str = ".";
        DT = Class<UTDamageType>(OptionalObject);
        if (DT != None)
        {
            if (DT.default.DamageWeaponClass != none)
                Str = DT.default.DamageWeaponClass.default.ItemName;
            else if ((class<UTDmgType_RanOver>(DT) != none) || (DT.default.KillStatsName == 'KILLS_SCORPIONBLADE'))
                Str = RunOverString;
            else if (DT.default.KillStatsName == 'KILLS_SPIDERMINE')
                Str = SpiderMineString;
            else if (DT.default.KillStatsName == 'KILLS_SCORPIONSELFDESTRUCT')
                Str = ScorpionKamikazeString;
            else if (DT.default.KillStatsName == 'KILLS_VIPERSELFDESTRUCT')
                Str = ViperKamikazeString;
            else if (DT.default.KillStatsName == 'KILLS_TRANSLOCATOR')
                Str = TelefragString;
        }
        if (Str != ".")
            Str = " (" $ Str $ ").";

        if (RelatedPRI_1 == none)
            ReporterMessage(PRI2Name @ "killed" @ (RelatedPRI_2.bIsFemale ?
                "herself" : "himself") $ Str, 'Kill');
        else
            ReporterMessage(PRI1Name @ "killed" @ PRI2Name $ Str, 'Kill');
    }
    else if (ClassIsChildOf(Message, class'UTFirstBloodMessage'))
    {
        ReporterMessage(PRI1Name @ "drew first blood!", 'FirstBlood');
    }
    else if (ClassIsChildOf(Message, class'UTKillingSpreeMessage'))
    {
        if (RelatedPRI_2 == none)
        {
            ReporterMessage(PRI1Name @ class'UTKillingSpreeMessage'.default.SpreeNote[Switch], 'Spree');
        }
        else
        {
            if (RelatedPRI_1 == RelatedPRI_2 || RelatedPRI_1 == none)
            {
                Str = RelatedPRI_2.bIsFemale ?
                    "ended her own killing spree." :
                    "ended his own killing spree.";
                ReporterMessage(PRI2Name @ Str, 'Spree');
            }
            else
            {
                Str = class'UTKillingSpreeMessage'.default.EndSpreeNote;
                ReporterMessage(PRI1Name $ Str @ PRI2Name, 'Spree');
            }
        }
    }
    else if (ClassIsChildOf(Message, class'UTCarriedObjectMessage'))
    {
        Str = (Switch < 7 ? "Red" : "Blue");

        if (Message == class'UTCTFMessage')
            Str @= "flag";
        else if (Message == class'UTOnslaughtOrbMessage')
            Str @= "orb";
        else
            Str @= "item";

        Str = IrcBold(IrcColor(Str, GetTeamIrcColor(Switch < 7 ? 0 : 1)));

        switch (Switch % 7)
        {
            case 0:
                Str @= "captured by" @ PRI1Name;
                break;
            case 1:
                Str @= "returned by" @ PRI1Name;
                break;
            case 2:
                Str @= "dropped by" @ PRI1Name;
                break;
            case 3:
                Str @= "returned";
                break;
            case 4:
                Str @= "picked up by" @ PRI1Name;
                break;
            case 5:
                Str @= "returned";
                break;
            case 6:
                Str @= "taken by" @ PRI1Name;
                break;
        }

        ReporterMessage(Str $ ".", 'CarriedObject');
    }
    else if (ClassIsChildOf(Message, class'UTTeamScoreMessage'))
    {
        if (Switch < 6)
        {
            switch (Switch / 2)
            {
                case 0:
                    ReporterMessage(FormatTeamName(Switch % 2) @ "scores!", 'TeamScore');
                    break;
                case 1:
                    ReporterMessage(FormatTeamName(Switch % 2) @ "increases their lead!", 'TeamScore');
                    break;
                case 2:
                    ReporterMessage(FormatTeamName(Switch % 2) @ "has taken the lead!", 'TeamScore');
                    break;
            }
            ReporterMessage(ShortTeamScores(), 'TeamScore');
        }
    }
    else if (ClassIsChildOf(Message, class'UTTimerMessage'))
    {
        if (Switch == 17)
        {
            ReporterMessage("Overtime!", 'Overtime');
        }
    }
    // TODO: better onslaught support
    else if (ClassIsChildOf(Message, class'UTOnslaughtMessage'))
    {
        Str = UTGameObjective(OptionalObject).ObjectiveName @ "node";

        switch (Switch)
        {
            case 0:
            case 1:
                ReporterMessage(FormatTeamName(Switch - 0,, true) @ "wins the round!", 'Onslaught');
                break;
            case 2:
            case 3:
                ReporterMessage(FormatTeamName(Switch - 2,, true) @ "power node constructed.", 'Onslaught');
                break;
            case 4:
                ReporterMessage("Draw - both cores drained!", 'Onslaught');
                break;
            case 9:
            case 10:
//                ReporterMessage(FormatTeamName(Switch - 9,, true) @ "Prime Node under attack!", 'Onslaught');
                break;
            case 11:
                ReporterMessage("2 points for regulation win.", 'Onslaught');
                break;
            case 12:
                ReporterMessage("1 point for overtime win.", 'Onslaught');
                break;
            case 16:
            case 17:
                ReporterMessage(FormatTeamName(Switch - 2,, true) @ "power node destroyed.", 'Onslaught');
                break;
            case 23:
            case 24:
                ReporterMessage(FormatTeamName(Switch - 23,, true) @ "power node under construction.", 'Onslaught');
                break;
            case 27:
            case 28:
                ReporterMessage(FormatTeamName(Switch - 27,, true) @ "power node isolated!", 'Onslaught');
                break;
        }
    }
    else if (ClassIsChildOf(Message, class'UTOnslaughtBlueCoreMessage'))
    {
        if (ClassIsChildOf(Message, class'UTOnslaughtRedCoreMessage'))
            Str = FormatTeamName(0, "Red core");
        else
            Str = FormatTeamName(1, "Blue core");

        switch (Switch)
        {
            case 0:
//                ReporterMessage(Str @ "is under attack!", 'OnslaughtCore');
                break;
            case 1:
                ReporterMessage(Str @ "destroyed!", 'OnslaughtCore');
                break;
            case 2:
                ReporterMessage(Str @ "is critical!", 'OnslaughtCore');
                break;
            case 3:
                ReporterMessage(Str @ "is vulnerable!", 'OnslaughtCore');
                break;
            case 4:
                ReporterMessage(Str @ "is heavily damaged!", 'OnslaughtCore');
                break;
            case 6:
                ReporterMessage(Str @ "is secure!", 'OnslaughtCore');
                break;
        }
    }
    else
    {
        ReporterMessage(Message.static.GetString(Switch,, RelatedPRI_1, RelatedPRI_2, OptionalObject), 'Misc');
    }
}

function NotifyLogin(Controller Entering)
{
    local PlayerInfo Player, P;
    local string Str;

    if (Entering == none || Entering.PlayerReplicationInfo == none)
        return;

    foreach Players(P)
    {
        if (P.Controller == Entering)
            return;
    }

    if (Entering.PlayerReplicationInfo.bOnlySpectator)
        Str = "connected as spectator.";
    else
        Str = "connected.";
    ReporterMessage(FormatPlayerName(Entering.PlayerReplicationInfo) @ Str, 'Connected');
    Player.Controller = Entering;
    Players.AddItem(Player);

    UpdateReporterTopic();
}

function NotifyLogout(Controller Exiting)
{
    if (Exiting == none || Exiting.PlayerReplicationInfo == none)
        return;
    ReporterMessage(FormatPlayerName(Exiting.PlayerReplicationInfo) @ "disconnected.", 'Disconnected');

    UpdateReporterTopic();
}

function UpdatePlayers()
{
    local int i;
    local int OldTeam;
    local string Str;

    for (i = 0; i < Players.Length; ++i)
    {
        if (Players[i].Controller == none)
        {
            Players.Remove(i--, 1);
            continue;
        }

        if (Players[i].PRI == none)
        {
            Players[i].PRI = Players[i].Controller.PlayerReplicationInfo;
            Players[i].PlayerName = Players[i].PRI.GetPlayerAlias();
            Players[i].Team = GetTeamIdx(Players[i].PRI);
            Players[i].Score = int(Players[i].PRI.Score);
        }

        if (Players[i].PlayerName != Players[i].PRI.GetPlayerAlias())
        {
            ReporterMessage(FormatPlayerName(Players[i].PRI, Players[i].PlayerName) @
                "changed name to" @ FormatPlayerName(Players[i].PRI), 'NameChange');
            Players[i].PlayerName = Players[i].PRI.GetPlayerAlias();
        }

        if (Players[i].Team != GetTeamIdx(Players[i].PRI))
        {
            OldTeam = Players[i].Team;
            Players[i].Team = GetTeamIdx(Players[i].PRI);
            Log(Players[i].PlayerName @ "team change from" @ OldTeam @ "to" @ Players[i].Team, LL_Debug);
            Str = FormatPlayerName(Players[i].PRI,, OldTeam);
            if (Players[i].Team >= 0)
            {
                ReporterMessage(Str @ "joined the" @ FormatTeamName(Players[i].Team) $ ".", 'TeamChange');
            }
            else if (Players[i].Team == -1 && OldTeam == -2)
            {
                ReporterMessage(Str @ "joined the game.", 'TeamChange');
            }
            else if (Players[i].Team == -2)
            {
                ReporterMessage(Str @ "became a spectator.", 'TeamChange');
            }
        }
    }
}

function CheckGameStatus()
{
    local name GameInfoState;
    local array<string> Arr;
    local string Str;

    GameInfoState = WorldInfo.Game.GetStateName();
    if (GameInfoState != LastGameInfoState)
    {
        LastGameInfoState = GameInfoState;
        switch(GameInfoState)
        {
            case 'PendingMatch':
                UpdateReporterTopic();
                ReporterMessage(GameStatus(), 'GameStatus');
                break;
            case 'MatchOver':
                ReporterMessage("Match has ended.", 'MatchOver');
                ReporterMessage(LongTeamScores(), 'MatchOver');
                Arr = PlayerScores();
                foreach Arr(Str)
                {
                    ReporterMessage(Str, 'MatchOver');
                }
                break;
            case 'RoundOver':
                ReporterMessage("Round has ended.", 'RoundOver');
                ReporterMessage(LongTeamScores(), 'RoundOver');
                Arr = PlayerScores();
                foreach Arr(Str)
                {
                    ReporterMessage(Str, 'RoundOver');
                }
                break;
        }
    }
}

function InGameChat(string Nick, string Text)
{
    ReporterSpectator.ServerSay(Nick $ ":" @ StripFormat(Text));
}

function bool IsAdmin(string Host)
{
    local string AdminMask;

    foreach AdminHostmasks(AdminMask)
    {
        if (MatchString(AdminMask, Host))
            return true;
    }
    return false;
}

function bool IsIgnored(string Host)
{
    local string IgnoreMask;
    
    if (IsAdmin(Host))
        return false;

    foreach IgnoreHostmasks(IgnoreMask)
    {
        if (MatchString(IgnoreMask, Host))
            return true;
    }
    return false;
}

function Reply(string Host, string Target, string Text, optional bool bPrivate = true)
{
    if (bPrivate)
    {
        NOTICE(ParseHostmask(Host).Nick, Text);
    }
    else
    {
        if (IsChannel(Target))
            ChannelMessage(Target, Text, false);
        else
            PRIVMSG(ParseHostmask(Host).Nick, Text);
    }
}

function HandleCommand(string Text, IrcMessage Message)
{
    local string Cmd, Arg;
    local ReporterCommand Command;
    local delegate<ReporterCommandDelegate> Handler;

    Split2(" ", Text, Cmd, Arg);

    Log("Received command: " $ Cmd, LL_Debug);
    foreach Commands(Command)
    {
        if (Command.CommandName ~= Cmd)
        {
            Handler = Command.Handler;
            Handler(Message.Prefix, Message.Params[0], Arg);
            return;
        }
    }
    Reply(Message.Prefix, Message.Params[0], "Unknown command \"" $ Cmd $
        "\" - type " $ CommandPrefix $ "commands to see a list of commands.");
}

////////// Commands

function Command_commands(string Host, string Target, string Arg)
{
    local string Str;
    local ReporterCommand Command;

    Str = "Commands:";
    foreach Commands(Command)
    {
        if (!Command.bHidden)
            Str @= Locs(Command.CommandName);
    }

    Reply(Host, Target, Str);
}

function Command_help(string Host, string Target, string Arg)
{
    local ReporterCommand Command;

    if (Arg == "")
    {
        Reply(Host, Target,
            "Give a command name to see its description." @
            "Type " $ CommandPrefix $ "commands to see a list of commands.");
    }
    else
    {
        foreach Commands(Command)
        {
            if (Command.CommandName ~= Arg)
            {
                Reply(Host, Target,
                    "Usage: " $ Command.Usage);
                Reply(Host, Target,
                    Command.Description);
                return;
            }
        }
    }
}

function Command_players(string Host, string Target, string Arg)
{
    local string Str;
    local array<PlayerReplicationInfo> PRIArray;
    local PlayerReplicationInfo PRI;

    WorldInfo.GRI.SortPRIArray();
    WorldInfo.GRI.GetPRIArray(PRIArray);
    Str = "";
    foreach PRIArray(PRI)
    {
        if (IrcSpectator(PRI.Owner) != none)
            continue;

        if (Str != "")
            Str $= " ";
        Str $= FormatPlayerName(PRI) $ "(" $
            (PRI.bOnlySpectator ? "Spec" : string(int(PRI.Score))) $ ")";
    }
    if (Str == "")
        Str = "The server is empty.";
    Reply(Host, Target, Str, false);
}

function Command_scores(string Host, string Target, string Arg)
{
    local array<string> Arr;
    local string Str;

    Reply(Host, Target, LongTeamScores(), false);
    Arr = PlayerScores();
    if (Arr.Length > 0)
    {
        foreach Arr(Str)
        {
            Reply(Host, Target, Str, false);
        }
    }
    else
    {
        Reply(Host, Target, "There are no players on the server.", false);
    }
}

function Command_status(string Host, string Target, string Arg)
{
    Reply(Host, Target, GameStatus(), false);
}

function Command_say(string Host, string Target, string Arg)
{
    local ReporterChannelConfig Conf;

    Conf = GetChannelConfig(Target);
    if (Conf != none && Conf.bEnableSay)
        InGameChat(ParseHostmask(Host).Nick, Arg);
}

function Command_raw(string Host, string Target, string Arg)
{
    if (IsAdmin(Host))
    {
        SendLine(Arg);
    }
    else
    {
        Reply(Host, Target, "You don't have permission to do that.");
    }
}

function Command_admin(string Host, string Target, string Arg)
{
    if (IsAdmin(Host))
    {
        Log("Admin command:" @ Arg, LL_Notice);
        ConsoleCommand(Arg);
    }
    else
    {
        Reply(Host, Target, "You don't have permission to do that.");
    }
}

function Command_topicformat(string Host, string Target, string Arg)
{
    local ReporterChannelConfig Conf;

    Conf = GetChannelConfig(Target);
    if (Conf == none)
        return;

    if (Arg == "")
    {
        Reply(Host, Target, "Current topic format is:" @ Conf.TopicFormat);
        return;
    }

    if (IsAdmin(Host))
    {
        Conf.TopicFormat = Arg;
        Conf.SaveConfig();
        UpdateReporterTopic();
        return;
    }
    else
    {
        Reply(Host, Target, "You don't have permission to do that.");
    }
}

function Command_motd(string Host, string Target, string Arg)
{
    local ReporterChannelConfig Conf;

    Conf = GetChannelConfig(Target);
    if (Conf == none)
        return;

    if (Arg == "")
    {
        Reply(Host, Target, "Current message of the day is:" @ Conf.Motd);
        return;
    }

    if (IsAdmin(Host))
    {
        Conf.Motd = Arg;
        Conf.SaveConfig();
        UpdateReporterTopic();
        return;
    }
    else
    {
        Reply(Host, Target, "You don't have permission to do that.");
    }
}

function Command_ignore(string Host, string Target, string Arg)
{
    local string IgnoreMask;

    if (Arg == "")
    {
        Reply(Host, Target, "Missing parameter.");
        return;
    }

    if (IsAdmin(Host))
    {
        foreach IgnoreHostmasks(IgnoreMask)
        {
            if (IgnoreMask ~= Arg)
            {
                Reply(Host, Target, Arg @ "is already in the ignore list.");
                return;
            }
        }

        IgnoreHostmasks.AddItem(Arg);
        default.IgnoreHostmasks.AddItem(Arg);
        StaticSaveConfig();
        Reply(Host, Target, Arg @ "added to the ignore list.");
        return;
    }
    else
    {
        Reply(Host, Target, "You don't have permission to do that.");
    }
}

function Command_unignore(string Host, string Target, string Arg)
{
    local int i;

    if (Arg == "")
    {
        Reply(Host, Target, "Missing parameter.");
        return;
    }

    if (IsAdmin(Host))
    {
        for (i = 0; i < Commands.Length; i++)
        {
            if (IgnoreHostmasks[i] ~= Arg)
            {
                IgnoreHostmasks.Remove(i, 1);
                default.IgnoreHostmasks.Remove(i, 1);
                StaticSaveConfig();
                Reply(Host, Target, Arg @ "removed from the ignore list.");
                return;
            }
        }
        Reply(Host, Target, Arg @ "is not in the ignore list.");
    }
    else
    {
        Reply(Host, Target, "You don't have permission to do that.");
    }
}

function Command_ignorelist(string Host, string Target, string Arg)
{
    local string IgnoreMask;

    if (IsAdmin(Host))
    {
        Reply(Host, Target, "Ignore list:");

        foreach IgnoreHostmasks(IgnoreMask)
        {
            Reply(Host, Target, IgnoreMask);
        }
    }
    else
    {
        Reply(Host, Target, "You don't have permission to do that.");
    }
}

function Command_wut(string Host, string Target, string Arg)
{
    Reply(Host, Target, IrcBold("wut"), false);
}

////////// IRC handlers

function IrcReporter_Handler_JOIN(IrcMessage Message)
{
    local ReporterChannelConfig Conf;

    if (ParseHostmask(Message.Prefix).Nick ~= CurrentNick)
    {
        Conf = GetChannelConfig(Message.Params[0]);
        if (ShowMessage(Conf, 'GameStatus'))
            ChannelMessage(Message.Params[0], GameStatus());
        SetTimer(2, false, 'UpdateReporterTopic');
    }
}

function IrcReporter_Handler_PRIVMSG(IrcMessage Message)
{
    local ReporterChannelConfig Conf;

    if (IsIgnored(Message.Prefix))
        return;

    Conf = GetChannelConfig(Message.Params[0]);

    if (Left(Message.Params[1], Len(CommandPrefix)) == CommandPrefix)
    {
        HandleCommand(Mid(Message.Params[1], Len(CommandPrefix)), Message);
    }
    else if (IsChannel(Message.Params[0]))
    {
        if (!Conf.bRequireSayCommand)
            HandleCommand("say" @ Message.Params[1], Message);
    }
    else
    {
        HandleCommand(Message.Params[1], Message);
    }
}

defaultproperties
{
    RunOverString="Hit and Run"
    SpiderMineString="Spider Mine"
    ScorpionKamikazeString="Scorpion Self Destruct"
    ViperKamikazeString="Viper Self Destruct"
    TelefragString="Telefrag"

    ReporterSpectatorClass="IrcReporter.IrcSpectator"

    Server="irc.example.org"
    ServerPort=6667
    NickName="ut3reporter"
    UserName="ut3irc"
    RealName="UT3 IRC Reporter"
    CommandPrefix="!"

    GameRulesClass=class'UTGameRules_IrcReporter'

    VersionString="UT3 IrcReporter - SVN $Rev$"

    bRejoinOnKick=true
}
