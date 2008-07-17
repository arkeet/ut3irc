//-----------------------------------------------------------
// $Id$
//-----------------------------------------------------------
class IrcReporter extends IrcClient
    config(IrcReporter);

var config string ReporterServer;
var config string ReporterChannel;
var config string CommandPrefix;
var config array<string> AdminHostmasks;
var config array<string> ConnectCommands;

var config bool bEnableChat;
var config bool bEnableTwoWayChat;
var config bool bRequireSayCommand;
var config string ChatChannel;
var string RealChatChannel;

var config bool bSetTopic;
var config string TopicFormat;
var config string Motd;

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

struct MessageFilter
{
    var name MessageType;
    var bool bShow;
};

var config array<MessageFilter> MessageTypes;

struct ReporterCommand
{
    var string CommandName;
    var delegate<ReporterCommandDelegate> Handler;
    var bool bHidden;
};
var array<ReporterCommand> Commands;

delegate ReporterCommandDelegate(string Host, string Target, string Arg);

function RegisterCommand(delegate<ReporterCommandDelegate> Handler, string CommandName, optional bool bHiddenCmd = false)
{
    local ReporterCommand C;
    C.CommandName = CommandName;
    C.Handler = Handler;
    C.bHidden = bHiddenCmd;
    Commands.AddItem(C);
}

simulated function PostBeginPlay()
{
    super.PostBeginPlay();

    ReporterSpectator = Spawn(ReporterSpectatorClass);
    ReporterSpectator.Reporter = self;

    RealChatChannel = (ChatChannel == "" ? ReporterChannel : ChatChannel);

    RegisterHandler(IrcReporter_Handler_JOIN, "JOIN");
    RegisterHandler(IrcReporter_Handler_PRIVMSG, "PRIVMSG");

    RegisterCommand(Command_commands, "commands");
    RegisterCommand(Command_players, "players");
    RegisterCommand(Command_scores, "scores");
    RegisterCommand(Command_status, "status");
    RegisterCommand(Command_say, "say");
    RegisterCommand(Command_cmd, "cmd");
    RegisterCommand(Command_admin, "admin");
    RegisterCommand(Command_topicformat, "topicformat");
    RegisterCommand(Command_motd, "motd");

    RegisterCommand(Command_wut, "wut", true);

    Connect(ReporterServer);

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

    super.Registered();

    foreach ConnectCommands(Cmd)
    {
        Cmd = Repl(Cmd, "%n", CurrentNick);
        SendLine(Cmd);
    }
    JOIN(ReporterChannel);
    if (!(RealChatChannel ~= ReporterChannel))
        JOIN(RealChatChannel);
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

function ReporterMessage(string Text, optional bool bTimestamp = true)
{
    ChannelMessage(ReporterChannel, Text, bTimestamp);
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
        Log("Tried to set topic in" @ Channel @ "while not in the channel!", LL_Warning);
    }
}

function ReporterTopic(string Text)
{
    ChannelTopic(ReporterChannel, Text);
}

function ChatChannelMessage(string Text, optional bool bTimestamp = true)
{
    ChannelMessage(RealChatChannel, Text, bTimestamp);
}

function string StringRepeat(string Str, int Times)
{
    local string Result;
    Result = "";
    while (Times > 0)
    {
        Result $= Str;
        --Times;
    }
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

function AnnounceCurrentGame()
{
    ReporterMessage("Current game:" @ IrcBold(WorldInfo.Game.GameName)
        @ "on" @ IrcBold(WorldInfo.GetMapName()));
}

function ShowShortTeamScores()
{
    if (UTTeamGame(WorldInfo.Game) != none)
    {
        ReporterMessage("Current score:"
            @ FormatTeamName(0, int(UTTeamGame(WorldInfo.Game).Teams[0].Score))
            @ "-"
            @ FormatTeamName(1, int(UTTeamGame(WorldInfo.Game).Teams[1].Score))
            );
    }
}

const ColWidth = 24;

function ShowTeamScores()
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
        ReporterMessage(Str);
    }
}

function ShowPlayerScores()
{
    local array<PlayerReplicationInfo> PRIArray;
    local PlayerReplicationInfo PRI;
    local array<PlayerList> PlayerLists;
    local int i, j;
    local PlayerList L;
    local PlayerInfo Player;
    local int MaxPlayerListLen;
    local string Str;

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
        ReporterMessage(Str);
    }
}

function UpdateReporterTopic()
{
    local string NewTopic;

    if (!bSetTopic)
        return;

    NewTopic = Repl(TopicFormat, "%motd", Motd);
    NewTopic = Repl(NewTopic, "%gametype", WorldInfo.Game.GameName);
    NewTopic = Repl(NewTopic, "%map", WorldInfo.GetMapName());
    NewTopic = Repl(NewTopic, "%numplayers", WorldInfo.Game.GetNumPlayers());
    NewTopic = Repl(NewTopic, "%maxplayers", WorldInfo.Game.MaxPlayers);


    ReporterTopic(NewTopic);
}

function TeamMessage(PlayerReplicationInfo PRI, coerce string S, name Type, optional float MsgLifeTime)
{
    if (bEnableChat && Type == 'Say')
    {
        ChatChannelMessage(FormatPlayerName(PRI, PRI.GetPlayerAlias() $ ":") @ S, false);
    }
}

function bool ShowMessage(name MessageType)
{
    local MessageFilter F;

    foreach MessageTypes(F)
    {
        if (F.MessageType == MessageType)
            return F.bShow;
    }
    return (MessageType != 'Misc');
}

function ThrottleDropEvent()
{
    ReporterMessage("I had to drop some messages to catch up.");
    if (!(RealChatChannel ~= ReporterChannel))
        ChatChannelMessage("I had to drop some messages to catch up.");
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
        if (!ShowMessage('Startup'))
            return;

        if (Switch == 5)
            ReporterMessage("The match has begun!");
    }
    else if (ClassIsChildOf(Message, class'UTDeathMessage'))
    {
        if (!ShowMessage('Kill'))
            return;

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
            ReporterMessage(PRI2Name @ "killed" @ (RelatedPRI_2.bIsFemale ? "herself" : "himself") $ Str);
        else
            ReporterMessage(PRI1Name @ "killed" @ PRI2Name $ Str);
    }
    else if (ClassIsChildOf(Message, class'UTFirstBloodMessage'))
    {
        if (!ShowMessage('FirstBlood'))
            return;
        ReporterMessage(PRI1Name @ "drew first blood!");
    }
    else if (ClassIsChildOf(Message, class'UTKillingSpreeMessage'))
    {
        if (!ShowMessage('Spree'))
            return;

        if (RelatedPRI_2 == none)
        {
            ReporterMessage(PRI1Name @ class'UTKillingSpreeMessage'.default.SpreeNote[Switch]);
        }
        else
        {
            if (RelatedPRI_1 == RelatedPRI_2)
            {
                Str = RelatedPRI_1.bIsFemale ?
                    class'UTKillingSpreeMessage'.default.EndFemaleSpree :
                    class'UTKillingSpreeMessage'.default.EndSelfSpree;
                ReporterMessage(PRI1Name @ Str);
            }
            else
            {
                Str = class'UTKillingSpreeMessage'.default.EndSpreeNote;
                ReporterMessage(PRI1Name @ Str @ PRI2Name);
            }
        }
    }
    else if (ClassIsChildOf(Message, class'UTCarriedObjectMessage'))
    {
        if (!ShowMessage('CarriedObject'))
            return;

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

        ReporterMessage(Str $ ".");
    }
    else if (ClassIsChildOf(Message, class'UTTeamScoreMessage'))
    {
        if (!ShowMessage('TeamScore'))
            return;
        if (Switch < 6)
        {
            switch (Switch / 2)
            {
                case 0:
                    ReporterMessage(FormatTeamName(Switch % 2) @ "scores!");
                    break;
                case 1:
                    ReporterMessage(FormatTeamName(Switch % 2) @ "increases their lead!");
                    break;
                case 2:
                    ReporterMessage(FormatTeamName(Switch % 2) @ "has taken the lead!");
                    break;
            }
            ShowShortTeamScores();
        }
    }
    else if (ClassIsChildOf(Message, class'UTTimerMessage'))
    {
        if (!ShowMessage('Overtime'))
            return;
        if (Switch == 17)
        {
            ReporterMessage("Overtime!");
        }
    }
    // TODO: better onslaught support
    else if (ClassIsChildOf(Message, class'UTOnslaughtMessage'))
    {
        if (!ShowMessage('Onslaught'))
            return;

        Str = UTGameObjective(OptionalObject).ObjectiveName @ "node";

        switch (Switch)
        {
            case 0:
            case 1:
                ReporterMessage(FormatTeamName(Switch - 0,, true) @ "wins the round!");
                break;
            case 2:
            case 3:
                ReporterMessage(FormatTeamName(Switch - 2,, true) @ "power node constructed.");
                break;
            case 4:
                ReporterMessage("Draw - both cores drained!");
                break;
            case 9:
            case 10:
//                ReporterMessage(FormatTeamName(Switch - 9,, true) @ "Prime Node under attack!");
                break;
            case 11:
                ReporterMessage("2 points for regulation win.");
                break;
            case 12:
                ReporterMessage("1 point for overtime win.");
                break;
            case 16:
            case 17:
                ReporterMessage(FormatTeamName(Switch - 2,, true) @ "power node destroyed.");
                break;
            case 23:
            case 24:
                ReporterMessage(FormatTeamName(Switch - 23,, true) @ "power node under construction.");
                break;
            case 27:
            case 28:
                ReporterMessage(FormatTeamName(Switch - 27,, true) @ "power node isolated!");
                break;
        }
    }
    else if (ClassIsChildOf(Message, class'UTOnslaughtBlueCoreMessage'))
    {
        if (!ShowMessage('OnslaughtCore'))
            return;

        if (ClassIsChildOf(Message, class'UTOnslaughtRedCoreMessage'))
            Str = FormatTeamName(0, "Red core");
        else
            Str = FormatTeamName(1, "Blue core");

        switch (Switch)
        {
            case 0:
//                ReporterMessage(Str @ "is under attack!");
                break;
            case 1:
                ReporterMessage(Str @ "destroyed!");
                break;
            case 2:
                ReporterMessage(Str @ "is critical!");
                break;
            case 3:
                ReporterMessage(Str @ "is vulnerable!");
                break;
            case 4:
                ReporterMessage(Str @ "is heavily damaged!");
                break;
            case 6:
                ReporterMessage(Str @ "is secure!");
                break;
        }
    }
    else if (ShowMessage('Misc'))
    {
        ReporterMessage(Message.static.GetString(Switch,, RelatedPRI_1, RelatedPRI_2, OptionalObject));
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
    if (ShowMessage('Connected'))
        ReporterMessage(FormatPlayerName(Entering.PlayerReplicationInfo) @ Str);
    Player.Controller = Entering;
    Players.AddItem(Player);

    UpdateReporterTopic();
}

function NotifyLogout(Controller Exiting)
{
    if (Exiting == none || Exiting.PlayerReplicationInfo == none)
        return;
    if (ShowMessage('Disconnected'))
        ReporterMessage(FormatPlayerName(Exiting.PlayerReplicationInfo) @ "disconnected.");

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
            if (ShowMessage('NameChange'))
            {
                ReporterMessage(FormatPlayerName(Players[i].PRI, Players[i].PlayerName) @
                    "changed name to" @ FormatPlayerName(Players[i].PRI));
            }
            Players[i].PlayerName = Players[i].PRI.GetPlayerAlias();
        }

        if (Players[i].Team != GetTeamIdx(Players[i].PRI))
        {
            OldTeam = Players[i].Team;
            Players[i].Team = GetTeamIdx(Players[i].PRI);
            Log(Players[i].PlayerName @ "team change from" @ OldTeam @ "to" @ Players[i].Team, LL_Debug);
            if (ShowMessage('TeamChange'))
            {
                Str = FormatPlayerName(Players[i].PRI,, OldTeam);
                if (Players[i].Team >= 0)
                {
                    ReporterMessage(Str @ "joined the" @ FormatTeamName(Players[i].Team) $ ".");
                }
                else if (Players[i].Team == -1 && OldTeam == -2)
                {
                    ReporterMessage(Str @ "joined the game.");
                }
                else if (Players[i].Team == -2)
                {
                    ReporterMessage(Str @ "became a spectator.");
                }
            }
        }
    }
}

function CheckGameStatus()
{
    local name GameInfoState;

    GameInfoState = WorldInfo.Game.GetStateName();
    if (GameInfoState != LastGameInfoState)
    {
        LastGameInfoState = GameInfoState;
        switch(GameInfoState)
        {
            case 'PendingMatch':
                UpdateReporterTopic();
                if (!ShowMessage('GameStatus'))
                    break;
                AnnounceCurrentGame();
                break;
            case 'MatchOver':
                if (!ShowMessage('MatchOver'))
                    break;
                ReporterMessage("Match has ended.");
                ShowTeamScores();
                ShowPlayerScores();
                break;
            case 'RoundOver':
                if (!ShowMessage('RoundOver'))
                    break;
                ReporterMessage("Round has ended.");
                ShowTeamScores();
                ShowPlayerScores();
                break;
        }
    }
}

function InGameChat(string Nick, string Text)
{
    if (bEnableChat && bEnableTwoWayChat)
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

    NOTICE(ParseHostmask(Host).Nick, Str);
}

function Command_players(string Host, string Target, string Arg)
{
    local string Str;
    local array<PlayerReplicationInfo> PRIArray;
    local PlayerReplicationInfo PRI;

    if (Target ~= ReporterChannel)
    {
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
        ReporterMessage(Str);
    }
}

function Command_scores(string Host, string Target, string Arg)
{
    if (Target ~= ReporterChannel)
    {
        ShowTeamScores();
        ShowPlayerScores();
    }
}

function Command_status(string Host, string Target, string Arg)
{
    if (Target ~= ReporterChannel)
    {
        AnnounceCurrentGame();
    }
}

function Command_say(string Host, string Target, string Arg)
{
    if (Target ~= RealChatChannel)
    {
        InGameChat(ParseHostmask(Host).Nick, Arg);
    }
}

function Command_cmd(string Host, string Target, string Arg)
{
    if (IsAdmin(Host))
    {
        SendLine(Arg);
    }
    else
    {
        NOTICE(ParseHostmask(Host).Nick, "You don't have permission to do that.");
    }
}

function Command_admin(string Host, string Target, string Arg)
{
    if (IsAdmin(Host))
    {
        Log("Admin command:" @ Arg, LL_Debug);
        ReporterSpectator.Admin(Arg);
    }
    else
    {
        NOTICE(ParseHostmask(Host).Nick, "You don't have permission to do that.");
    }
}

function Command_topicformat(string Host, string Target, string Arg)
{
    if (Arg == "")
    {
        NOTICE(ParseHostmask(Host).Nick, "Current topic format is:" @ TopicFormat);
        return;
    }

    if (IsAdmin(Host))
    {
        TopicFormat = Arg;
        default.TopicFormat = Arg;
        UpdateReporterTopic();
        StaticSaveConfig();
        return;
    }
    else
    {
        NOTICE(ParseHostmask(Host).Nick, "You don't have permission to do that.");
    }
}

function Command_motd(string Host, string Target, string Arg)
{
    if (Arg == "")
    {
        NOTICE(ParseHostmask(Host).Nick, "Current message of the day is:" @ Motd);
        return;
    }

    if (IsAdmin(Host))
    {
        Motd = Arg;
        default.Motd = Arg;
        UpdateReporterTopic();
        StaticSaveConfig();
        return;
    }
    else
    {
        NOTICE(ParseHostmask(Host).Nick, "You don't have permission to do that.");
    }
}

function Command_wut(string Host, string Target, string Arg)
{
    if (!IsChannel(Target))
        Target = ParseHostmask(Host).Nick;
    PRIVMSG(Target, "wut");
}

////////// IRC handlers

function IrcReporter_Handler_JOIN(IrcMessage Message)
{
    if (Message.Params[0] ~= ReporterChannel && ParseHostmask(Message.Prefix).Nick ~= CurrentNick)
    {
        AnnounceCurrentGame();

        SetTimer(2, false, 'UpdateReporterTopic');
    }
}

function IrcReporter_Handler_PRIVMSG(IrcMessage Message)
{
    local string Cmd, Arg;
    local ReporterCommand Command;
    local delegate<ReporterCommandDelegate> Handler;

    if (Left(Message.Params[1], Len(CommandPrefix)) == CommandPrefix)
    {
        Split2(" ", Mid(Message.Params[1], Len(CommandPrefix)), Cmd, Arg);
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
        NOTICE(ParseHostmask(Message.Prefix).Nick, "Unknown command: " $ Cmd $
            " - type " $ CommandPrefix $ "commands to see a list of commands");
    }
    else if (Message.Params[0] ~= RealChatChannel && !bRequireSayCommand)
    {
        InGameChat(ParseHostmask(Message.Prefix).Nick, Message.Params[1]);
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

    bEnableChat=true
    bEnableTwoWayChat=true
    bRequireSayCommand=true

    bSetTopic=true
    TopicFormat=""
    Motd=""

    NickName="ut3reporter"
    RealName="UT3 IRC Reporter"
    ReporterServer="irc.gameradius.org"
    ReporterChannel="#ut3irc.test"
    CommandPrefix="!"

    GameRulesClass=class'UTGameRules_IrcReporter'

    VersionString="UT3 IrcReporter - SVN $Rev$"

    bRejoinOnKick=true
}

