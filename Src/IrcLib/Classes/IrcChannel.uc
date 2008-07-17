//-----------------------------------------------------------
// $Id$
//-----------------------------------------------------------
class IrcChannel extends Object
    dependson(IrcClient);

// TODO: handle modes with lists (such as ban lists)
// or perhaps ignore them

struct ChannelUser
{
    var string Nick;
    var string Prefix;
};

struct ChannelMode
{
    var string ModeChar;
    var string Parameter;
};

var IrcClient Irc;

var string Channel;
var string Topic;
var array<ChannelMode> Modes;
var array<ChannelUser> Users;

function Join(string Nick)
{
    local ChannelUser U, NewUser;

    foreach Users(U)
    {
        if (U.Nick ~= Nick)
        {
            Irc.Log(Nick @ "joined" @ Channel @ "when the channel already has" @ U.Nick,
                LL_Warning);
            return;
        }
    }

    NewUser.Nick = Nick;
    Users.AddItem(NewUser);
    Irc.Log(Nick @ "joined" @ Channel, LL_Debug);
}

function Part(string Nick)
{
    local int i;

    for (i = 0; i < Users.Length; ++i)
    {
        if (Users[i].Nick ~= Nick)
            Users.Remove(i--, 1);
    }
    Irc.Log(Nick @ "left" @ Channel, LL_Debug);
}

function NickChange(string OldNick, string NewNick)
{
    local ChannelUser U;
    local int i;

    foreach Users(U, i)
    {
        if (U.Nick == OldNick)
            Users[i].Nick = NewNick;
    }
}

function bool IsUserMode(string ModeChar, optional out string PrefixChar)
{
    local int Pos;

    Pos = InStr(Irc.UserModes, ModeChar);
    if (Pos == -1)
        return false;
    PrefixChar = Mid(Irc.UserModes, Pos, 1);
    return true;
}

function bool HasParameter(string ModeChar, bool bIsSet)
{
    if (IsUserMode(ModeChar))
        return true;
    if (bIsSet)
        return (InStr(Irc.ChanModesA $ Irc.ChanModesB $ Irc.ChanModesC, ModeChar) != -1);
    else
        return (InStr(Irc.ChanModesA $ Irc.ChanModesB, ModeChar) != -1);
}

function string SortPrefix(string Prefix)
{
    local string PrefixChar, Result;
    local int i;

    for (i = 0; i < Len(Irc.UserModePrefixes); i++)
    {
        PrefixChar = Mid(Irc.UserModePrefixes, i, 1);
        if (InStr(Prefix, PrefixChar) != -1)
            Result $= PrefixChar;
    }
    return Result;
}

function ParseMode(array<string> Params, int ModeOffset)
{
    local string ModeString, ModeChar, PrefixChar, Parameter;
    local ChannelUser User;
    local ChannelMode Mode, NewMode;
    local bool bModeOn, bFound;
    local int i, j;

    ModeString = Params[ModeOffset];

    for (i = 0; i < Len(ModeString); ++i)
    {
        ModeChar = Mid(ModeString, i, 1);
        if (ModeChar == "+" || ModeChar == "-")
        {
            bModeOn = (ModeChar == "+");
        }
        else if (IsUserMode(ModeChar, PrefixChar))
        {
            Parameter = Params[++ModeOffset];
            foreach Users(User)
            {
                if (User.Nick ~= Parameter)
                {
                    User.Prefix = SortPrefix(User.Prefix $ PrefixChar);
                    break;
                }
            }
        }
        else
        {
            NewMode.ModeChar = ModeChar;
            if (HasParameter(ModeChar, bModeOn))
                Parameter = Params[++ModeOffset];
            else
                Parameter = "";
            NewMode.Parameter = Parameter;

            Irc.Log(Channel @ "setting mode " $ (bModeOn ? "+" : "-") $
                ModeChar @ Parameter, LL_Debug);

            bFound = false;
            foreach Modes(Mode, j)
            {
                if (Mode.ModeChar == ModeChar)
                {
                    bFound = true;
                    if (bModeOn)
                        Modes[j] = NewMode;
                    else
                        Modes.Remove(j, 1);
                    break;
                }
            }
            if (bModeOn && !bFound)
                Modes.AddItem(NewMode);
        }
    }
}

function bool HasMode(string ModeChar, optional out string Parameter)
{
    local ChannelMode Mode;

    foreach Modes(Mode)
    {
        if (Mode.ModeChar == ModeChar)
        {
            Parameter = Mode.Parameter;
            return true;
        }
    }
    return false;
}

function ProcessUserList(string UserList)
{
    local string User;
    local ChannelUser U;

    Users.Length = 0;

    Irc.Log("Begin user list for" @ Channel, LL_Debug);
    while (Len(UserList) > 0)
    {
        Irc.Split2(" ", UserList, User, UserList);
        for (U.Prefix = ""; Len(User) > 0 && InStr(Irc.UserModePrefixes, Left(User, 1)) >= 0; User = Mid(User, 1))
        {
            U.Prefix $= Left(User, 1);
        }
        U.Prefix = SortPrefix(U.Prefix);
        U.Nick = User;
        Irc.Log(" - " $ U.Prefix $ U.Nick, LL_Debug);
    }
    Irc.Log("End user list", LL_Debug);
}

function SendMessage(string Text)
{
    if (HasMode("c"))
        Text = Irc.StripFormat(Text);
    Irc.PRIVMSG(Channel, Text);
}

function SetTopic(string Text)
{
    if (Topic != Text)
        Irc.TOPIC(Channel, Text);
}


defaultproperties
{
}
