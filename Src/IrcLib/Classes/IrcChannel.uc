//-----------------------------------------------------------
// $Id$
//-----------------------------------------------------------
class IrcChannel extends Object
    dependson(IrcClient);

var string UserModeChars;

struct ChannelUser
{
    var string Nick;
    var string Mode;
};

struct ChannelMode
{
    var string ModeChar;
    var string Argument;
};

var IrcClient Irc;

var string Channel;
var string Topic;
var array<ChannelMode> Modes;
var array<ChannelUser> Users;

function bool ModeCharHasArgument(string ModeChar)
{
    // TODO: is this all we need?
    return (InStr("vholkb", ModeChar) != -1);
}

function ParseMode(array<string> Params, int ModeOffset)
{
    // TODO: handle modes with arguments, including user op/voice/etc modes

    local string ModeString, ModeChar;
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
        else
        {
            NewMode.ModeChar = ModeChar;
            if (ModeCharHasArgument(ModeChar))
                NewMode.Argument = Params[++ModeOffset];
            else
                NewMode.Argument = "";

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

function bool HasMode(string ModeChar, optional out string Argument)
{
    local ChannelMode Mode;

    foreach Modes(Mode)
    {
        if (Mode.ModeChar == ModeChar)
        {
            Argument = Mode.Argument;
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
        for (U.Mode = ""; Len(User) > 0 && InStr(UserModeChars, Left(User, 1)) >= 0; User = Mid(User, 1))
        {
            U.Mode $= Left(User, 1);
        }
        U.Nick = User;
        Irc.Log("- " $ "(" $ (U.Mode == "" ? " " : U.Mode) $ ")" $ U.Nick, LL_Debug);
    }
    Irc.Log("End user list", LL_Debug);
}

function SendMessage(string Text)
{
    if (HasMode("c"))
        Text = Irc.StripFormat(Text);
    Irc.PRIVMSG(Channel, Text);
}

defaultproperties
{
    UserModeChars="~&@%+"
}
