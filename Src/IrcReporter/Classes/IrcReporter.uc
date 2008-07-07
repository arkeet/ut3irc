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
    var TeamInfo Team;
    var byte TeamIdx;
    var int Score;
    var bool bSpectator;
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

simulated function PostBeginPlay()
{
    super.PostBeginPlay();

    ReporterSpectator = Spawn(ReporterSpectatorClass);
    ReporterSpectator.Reporter = self;

    RealChatChannel = (ChatChannel == "" ? ReporterChannel : ChatChannel);

    RegisterHandler(IrcReporter_Handler_JOIN, "JOIN");
    RegisterHandler(IrcReporter_Handler_PRIVMSG, "PRIVMSG");
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
    // Does this even happen?
    QUIT("Bye");
    ReporterSpectator.Destroy();
}

function Registered()
{
    local string Cmd;

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

function ReporterMessage(string Text, optional bool bNoTimestamp)
{
    local IrcChannel C;

    C = GetChannel(ReporterChannel);
    if (C != none)
    {
        if (!bNoTimestamp)
            Text = GetTimestamp() $ Text;
        C.SendMessage(Text);
    }
    else
    {
        Log("Tried to send a reporter message while not in the channel!", LL_Warning);
    }
}

function ChatChannelMessage(string Text, optional bool bNoTimestamp)
{
    local IrcChannel C;

    C = GetChannel(RealChatChannel);
    if (C != none)
    {
        if (!bNoTimestamp)
            Text = GetTimestamp() $ Text;
        C.SendMessage(Text);
    }
    else
    {
        Log("Tried to send a chat message while not in the channel!", LL_Warning);
    }
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

function string GetTeamName(byte Team)
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
        default:
            return "No Team";
    }
}

function byte GetTeamIrcColor(byte Team)
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
        default:
            return IrcGreen;
    }
}

function string FormatPlayerName(PlayerReplicationInfo PRI, optional coerce string Text)
{
    if (Text == "")
        Text = PRI.GetPlayerAlias();
    return IrcBold(IrcColor(Text, GetTeamIrcColor(
        PRI.Team == none ? byte(255) : PRI.GetTeamNum())));
}

function string FormatTeamName(int Team, optional coerce string Text)
{
    if (Text == "")
        Text = GetTeamName(byte(Team));
    return IrcBold(IrcColor(Text, GetTeamIrcColor(byte(Team))));
}

function string FormatScoreListEntry(string ScoreName, int Score, byte Team, int Width)
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

const ColWidth = 24;

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
    local PlayerReplicationInfo PRI;
    local array<PlayerList> PlayerLists;
    local int i, j;
    local PlayerList L;
    local PlayerInfo Player;
    local int MaxPlayerListLen;
    local string Str;

    PlayerLists.Length = WorldInfo.Game.bTeamGame ? 2 : 1;
    MaxPlayerListLen = 0;

    foreach WorldInfo.GRI.PRIArray(PRI)
    {
        if (PRI.bOnlySpectator)
            continue;

        Player.PRI = PRI;
        Player.PlayerName = PRI.GetPlayerAlias();
        Player.TeamIdx = WorldInfo.Game.bTeamGame ? PRI.GetTeamNum() : byte(255);
        Player.Score = PRI.Score;

        i = Player.TeamIdx >= 2 ? 0 : int(Player.TeamIdx);
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
                Str $= FormatScoreListEntry(Player.PlayerName, Player.Score, Player.TeamIdx, ColWidth);
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

function TeamMessage(PlayerReplicationInfo PRI, coerce string S, name Type, optional float MsgLifeTime)
{
    if (bEnableChat && Type == 'Say')
    {
        ChatChannelMessage(FormatPlayerName(PRI, PRI.GetPlayerAlias() $ ":") @ S);
    }
}

function bool ShowMessage(name MessageType)
{
    local MessageFilter F;

    Log("ShowMessage" @ MessageType, LL_Debug);

    foreach MessageTypes(F)
    {
        if (F.MessageType == MessageType)
            return F.bShow;
    }
    return (MessageType != 'Misc');
}

function ThrottleMessage()
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
    else if (ShowMessage('Misc'))
    {
        ReporterMessage(Message.static.GetString(Switch,, RelatedPRI_1, RelatedPRI_2, OptionalObject));
    }
}

function NotifyLogin(Controller Entering)
{
    local PlayerInfo Player;
    local string Str;

    if (Entering == none || Entering.PlayerReplicationInfo == none)
        return;

    if (Entering.PlayerReplicationInfo.bOnlySpectator)
        Str = "connected as spectator.";
    else
        Str = "connected.";
    if (ShowMessage('Connected'))
        ReporterMessage(FormatPlayerName(Entering.PlayerReplicationInfo) @ Str);
    Player.Controller = Entering;
    Players.AddItem(Player);
}

function NotifyLogout(Controller Exiting)
{
    if (Exiting == none || Exiting.PlayerReplicationInfo == none)
        return;
    if (ShowMessage('Disconnected'))
        ReporterMessage(FormatPlayerName(Exiting.PlayerReplicationInfo) @ "disconnected.");
}

function UpdatePlayers()
{
    local int i;

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
            Players[i].bSpectator = Players[i].PRI.bOnlySpectator;
            Players[i].PlayerName = Players[i].PRI.GetPlayerAlias();
            Players[i].Team = Players[i].PRI.Team;
            Players[i].TeamIdx = Players[i].PRI.GetTeamNum();
            Players[i].Score = int(Players[i].PRI.Score);
        }

        if (Players[i].PlayerName != Players[i].PRI.GetPlayerAlias())
        {
            if (ShowMessage('NameChange'))
                ReporterMessage(FormatPlayerName(Players[i].PRI, Players[i].PlayerName) @
                    "changed name to" @ FormatPlayerName(Players[i].PRI));
            Players[i].PlayerName = Players[i].PRI.GetPlayerAlias();
        }

        if (Players[i].bSpectator != Players[i].PRI.bOnlySpectator ||
            Players[i].Team != Players[i].PRI.Team)
        {
            Players[i].bSpectator = Players[i].PRI.bOnlySpectator;
            Players[i].Team = Players[i].PRI.Team;
            Players[i].TeamIdx = Players[i].PRI.GetTeamNum();
            if (ShowMessage('TeamChange'))
            {
                if (Players[i].bSpectator)
                {
                    ReporterMessage(FormatPlayerName(Players[i].PRI) @ "became a spectator.");
                }
                else if (Players[i].Team != none)
                {
                    ReporterMessage(FormatPlayerName(Players[i].PRI) @ "joined the" @
                        FormatTeamName(Players[i].TeamIdx) $ ".");
                }
                else
                {
                    ReporterMessage(FormatPlayerName(Players[i].PRI) @ "joined the game.");
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
        ReporterSpectator.ServerSay(Nick $ ":" @ Text);
}

////////// IRC handlers

function IrcReporter_Handler_JOIN(IrcMessage Message)
{
    if (Message.Params[0] ~= ReporterChannel && ParseHostmask(Message.Prefix).Nick == CurrentNick)
    {
        AnnounceCurrentGame();
    }
}

function IrcReporter_Handler_PRIVMSG(IrcMessage Message)
{
    local string Cmd, Arg;
    local string Str;
    local PlayerReplicationInfo PRI;

    if (Left(Message.Params[1], Len(CommandPrefix)) == CommandPrefix)
    {
        Split2(" ", Mid(Message.Params[1], Len(CommandPrefix)), Cmd, Arg);
        Log("Received command: " $ Cmd, LL_Debug);
        if (Message.Params[0] ~= ReporterChannel)
        {
            if (Cmd ~= "players")
            {
                Str = "";
                foreach WorldInfo.GRI.PRIArray(PRI)
                {
                    if (PRI.bOnlySpectator)
                        continue;

                    if (Str != "")
                        Str $= " ";
                    Str $= PRI.GetPlayerAlias() $ "(" $ int(PRI.Score) $ ")";
                }
                ReporterMessage(Str);
            }
            else if (Cmd ~= "scores")
            {
                ShowTeamScores();
                ShowPlayerScores();
            }
            else if (Cmd ~= "status")
            {
                AnnounceCurrentGame();
            }
        }
        if (Message.Params[0] ~= RealChatChannel)
        {
            if (Cmd ~= "say")
            {
                InGameChat(ParseHostmask(Message.Prefix).Nick, Arg);
            }
        }
        if (Cmd ~= "cmd")
        {
            foreach AdminHostmasks(Str)
            {
                if (MatchString(Str, Message.Prefix))
                {
                    SendLine(Arg);
                    break;
                }
            }
        }
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

    NickName="ut3reporter"
    RealName="UT3 IRC Reporter"
    ReporterServer="irc.gameradius.org"
    ReporterChannel="#ut3irc.test"
    CommandPrefix="!"

    GameRulesClass=class'UTGameRules_IrcReporter'

    VersionString="UT3 IrcReporter - SVN $Rev$"
}

