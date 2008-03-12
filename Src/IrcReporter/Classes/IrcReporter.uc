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

var class<IrcSpectator> ReporterSpectatorClass;
var IrcSpectator ReporterSpectator;

struct PlayerListEntry
{
    var PlayerReplicationInfo PRI;
    var string PlayerName;
    var byte Team;
    var int Score;
};

struct PlayerList
{
    var array<PlayerListEntry> Entries;
};

simulated function PostBeginPlay()
{
    super.PostBeginPlay();

    ReporterSpectator = Spawn(ReporterSpectatorClass);
    ReporterSpectator.Reporter = self;

    RegisterHandler(IrcReporter_Handler_JOIN, "JOIN");
    RegisterHandler(IrcReporter_Handler_PRIVMSG, "PRIVMSG");
    Connect(ReporterServer);
}

event Destroyed()
{
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
}

function ReporterMessage(string Text)
{
    local IrcChannel C;

    C = GetChannel(ReporterChannel);
    if (C != none)
        C.SendMessage(Text);
}

function string StringRepeat(string Str, int Times)
{
    local string Result;
    Result = "";
    while (Times > 0)
    {
        Result $= Str;
        Times--;
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

function ShowTeamScores()
{
    local string Str;
    local int i;
    local TeamInfo Team;

    if (UTTeamGame(WorldInfo.Game) != none)
    {
        Str = "";
        for (i = 0; i < 2; i++)
        {
            Team = UTTeamGame(WorldInfo.Game).Teams[i];
            if (i > 0)
                Str $= " | ";
            Str $= IrcBold(FormatScoreListEntry(GetTeamName(i), Team.Score, i, ColWidth));
        }
        ReporterMessage(Str);
    }
}

function ShowPlayerScores()
{
    local PlayerReplicationInfo PRI;
    local array<PlayerList> PlayerLists;
    local int i, j;
    local PlayerList L;
    local PlayerListEntry Player;
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
        Player.Team = WorldInfo.Game.bTeamGame ? PRI.GetTeamNum() : byte(255);
        Player.Score = PRI.Score;

        i = Player.Team >= 2 ? 0 : int(Player.Team);
        PlayerLists[i].Entries.AddItem(Player);
        MaxPlayerListLen = Max(PlayerLists[i].Entries.Length, MaxPlayerListLen);
    }

    for (i = 0; i < MaxPlayerListLen; i++)
    {
        Str = "";
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
        ReporterMessage(Str);
    }
}

function TeamMessage(PlayerReplicationInfo PRI, coerce string S, name Type, optional float MsgLifeTime)
{
    if (Type == 'Say')
    {
        ReporterMessage(IrcBold(PRI.GetPlayerAlias() $ ":") @ S);
    }
}

function ReceiveLocalizedMessage(class<LocalMessage> Message, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
    if (Message == class'UTStartupMessage')
    {
        if (Switch == 5)
            ReporterMessage("The match has begun!");
    }
    else
    {
        Log(self @ "ReceiveLocalizedMessage" @ Message @ Switch @
            RelatedPRI_1 @ RelatedPRI_2 @ OptionalObject, LL_Debug);
    }
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
            else if (Cmd ~= "say")
            {
                ReporterSpectator.ServerSay(ParseHostmask(Message.Prefix).Nick $ ":" @ Arg);
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
}

defaultproperties
{
    ReporterSpectatorClass="IrcReporter.IrcSpectator"

    NickName="ut3reporter"
    RealName="UT3 IRC Reporter"
    ReporterServer="irc.gameradius.org"
    ReporterChannel="#ut3irc.test"
    CommandPrefix="!"
}

