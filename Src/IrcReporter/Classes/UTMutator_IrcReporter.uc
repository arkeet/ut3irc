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
    ActorList[ActorList.length] = self;
    ActorList[ActorList.Length] = Reporter;
    ActorList[ActorList.Length] = Reporter.ReporterSpectator;

    if (NextMutator != None)
    {
        NextMutator.GetSeamlessTravelActorList(bToEntry, ActorList);
    }
}

defaultproperties
{
}
