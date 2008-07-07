//-----------------------------------------------------------
// $Id$
//-----------------------------------------------------------
class UTMutator_IrcReporter extends UTMutator;

var IrcReporter Reporter;

function PostBeginPlay()
{
    local IrcReporter R;

    if (Reporter == none)
    {
        foreach AllActors(class'IrcReporter', R)
        {
            Reporter = R;
            break;
        }
    }

    if (Reporter == none)
    {
        Reporter = Spawn(class'IrcReporter');
    }
}

function GetSeamlessTravelActorList(bool bToEntry, out array<Actor> ActorList)
{
    ActorList.AddItem(self);
    ActorList.AddItem(Reporter);
    ActorList.AddItem(Reporter.ReporterSpectator);
    ActorList.AddItem(Reporter.GameRules);

    if (NextMutator != None)
    {
        NextMutator.GetSeamlessTravelActorList(bToEntry, ActorList);
    }
}

function NotifyLogin(Controller Entering)
{
    super.NotifyLogin(Entering);
    if (Reporter != none)
    {
        Reporter.NotifyLogin(Entering);
    }
}

function NotifyLogout(Controller Exiting)
{
    super.NotifyLogout(Exiting);
    if (Reporter != none)
    {
        Reporter.NotifyLogout(Exiting);
    }
}

defaultproperties
{
}
