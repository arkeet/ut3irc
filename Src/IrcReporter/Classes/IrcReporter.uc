//-----------------------------------------------------------
//
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

    RegisterHandler(IrcReporter_Handler_PRIVMSG, "PRIVMSG");
    Connect(ReporterServer);
}

event Destroyed()
{
    ReporterSpectator.Destroy();
}

function Registered()
{
    local int i;
    local string Cmd;

    for (i = 0; i < ConnectCommands.Length; i++)
    {
        Cmd = ConnectCommands[i];
        Cmd = Repl(Cmd, "%n", CurrentNick);
        SendLine(Cmd);
    }
    JOIN(ReporterChannel);
    PRIVMSG(ReporterChannel, "Current game:" @ IrcBold(WorldInfo.Game.GameName)
        @ "on" @ IrcBold(WorldInfo.GetMapName()));
}

function ReporterMessage(string Text)
{
    local IrcChannel C;

    C = GetChannel(ReporterChannel);
    if (C != none)
        C.SendMessage(Text);
}

function ShowTeamScores()
{
}

function ShowPlayerScores()
{
    local PlayerReplicationInfo PRI;
    local array<PlayerList> PlayerLists;
    local PlayerListEntry Player;

    foreach WorldInfo.GRI.PRIArray(PRI)
    {
        if (PRI.bOnlySpectator)
            continue;

        Player.PRI = PRI;
        Player.PlayerName = PRI.GetPlayerAlias();
        Player.Team = WorldInfo.Game.bTeamGame ? PRI.GetTeamNum() : byte(255);
        Player.Score = PRI.Score;

        PlayerLists[Player.Team >= 2 ? 0 : int(Player.Team)].Entries.AddItem(Player);
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
    Log(self @ "ReceiveLocalizedMessage" @ Message @ Switch @
        RelatedPRI_1 @ RelatedPRI_2 @ OptionalObject, LL_Debug);
    if (Message == class'UTStartupMessage')
    {
        if (Switch == 5)
            ReporterMessage("The match has begun!");
    }
    else
    {
        ReporterMessage("~:" @ Message @ switch @ Message.static.GetString(Switch,, RelatedPRI_1, RelatedPRI_2, OptionalObject));
    }
}

////////// IRC handlers

function IrcReporter_Handler_PRIVMSG(IrcMessage Message)
{
    local string Cmd, Arg;
    local string Str;
    local int i;
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
                for (i = 0; i < WorldInfo.GRI.PRIArray.Length; i++)
                {
                    PRI = WorldInfo.GRI.PRIArray[i];
                    if (PRI.bOnlySpectator)
                        continue;

                    if (Str != "")
                        Str $= " ";
                    Str $= PRI.GetPlayerAlias() $ "(" $
                        int(PRI.Score) $ ")";
                }
                ReporterMessage(Str);
            }
            else if (Cmd ~= "scores")
            {
                ShowTeamScores();
                ShowPlayerScores();
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

