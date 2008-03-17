//-----------------------------------------------------------
//
//-----------------------------------------------------------
class UTGameRules_IrcReporter extends GameRules;

var IrcReporter Reporter;

simulated function PostBeginPlay()
{
    local IrcReporter R;

    foreach AllActors(class'IrcReporter', R)
    {
        Reporter = R;
        Reporter.GameRules = self;
        return;
    }
    if (Reporter == none)
        Destroy();
}

defaultproperties
{
}
