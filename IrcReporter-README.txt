
                                   UT3 IRC
                       http://ner.mine.nu:3080/ut3irc/
                            Authors: Nereid, Zer0

                               IRC Reporter Bot

------------------------------------------------------------------------------
 Installation
------------------------------------------------------------------------------

 * .u files go in UTGame\Published\CookedPC (in your UT3 user directory which
   is typically My Documents\My Games\Unreal Tournament 3).
 * .ini files go in UTGame\Config.

------------------------------------------------------------------------------
 Usage
------------------------------------------------------------------------------

First, configure the reporter bot (see Configuration below).  If you are
running a dedicated server, use ?Mutator=IrcReporter.UTMutator_IrcReporter.
If you are starting a game from within UT3, just add the IRC Reporter mutator.

------------------------------------------------------------------------------
 Configuration
------------------------------------------------------------------------------

All settings are configured in UTIrcReporter.ini.  Use the example
configuration to start with.

For general settings, edit the [IrcReporter.IrcReporter] section.  Most of the
settings are fairly obvious from their name.

 * Connection Settings
    - Server: The hostname of the IRC server to connect to.
    - ServerPort: The port of the IRC server to connect to.  Default: 6667
 * Throttle Settings
    - bThrottleEnable: If true, the bot will throttle outgoing IRC messages.
      Default:  True
    - ThrottleMaxPenalty: The maximum penalty (in seconds) allowed before
      throttling is activated.  No messages will be sent unless the penalty
      drops below this amount.  Default: 10.0
    - ThrottleMessagePenalty: The number of seconds a text message should add
      to the penalty.  Default: 2.0
    - ThrottleCommandPenalty: The number of seconds other IRC commands should
      add to the penalty. Default: 1.0
    - ThrottleMaxMessageQueue: The maximum number of messages that may be
      stored in the message queue. If more messages are added to the queue,
      the bot will simply drop all messages in the queue.
 * Other Settings
    - AdminHostmasks: A list of hostmasks for users that should be allowed to
      execute admin commands on the bot.
    - CommandPrefix: The bot has a number of commands, such as !status and
      !scores.  This setting lets you change the command prefix.
    - LogLevel: The minimum level of importants required for messages to be
      logged to the log file.  Possible values: LL_Debug, LL_Notice,
      LL_Warning, LL_Error.  Default is LL_Warning.  If you are having a
      problem with the bot, set this to LL_Debug to get (a lot of) debugging
      information.

The bot can report to several channels. Each channel needs its own section,
in the form of [#channel ReporterChannelConfig].

 * Reporting Settings
    - MessageTypes: A list of types of event messages and whether they should
      be reported to IRC. Each message type defaults to True.  The possible
      types are:
       - Chat: In-game chat.
       - Throttle: A message that is produced when the message queue exceeds
         the maximum length, as described above in Throttle Settings.
       - GameStatus: Game information at startup or on a new map.
       - Connected: A player connected to the server.
       - Disconnected: A player disconnected from the server.
       - NameChange: A player changes names.
       - TeamChange: A player changes teams, or changes spectator status.
       - Startup: The match started.
       - Kill: Death messages.
       - FirstBlood: A player draws first blood.
       - Spree: Killing sprees.
       - CarriedObject: Flag events in CTF and VCTF, and orb events in
         Warfare.
       - TeamScore: A team scores (except in TDM).
       - Onslaught: Warfare power node messages.
       - OnslaughtCore: Warfare power core messages.
       - Overtime: The game timer runs out.
       - MatchOver: The game ends.
       - RoundOver: The round ends in, for example, Warfare.
 * Chat Settings
    - bEnableSay: This setting determines whether the bot will relay chat from
      this channel on IRC to the game.  Default: True
    - bRequireSayCommand: If set, users on this channel must use !say to send
      chat to the game.  Default: True
    - See Chat in Reporting Settings above to 
 * Topic Settings
    - bSetTopic: If true, the bot will modify the channel topic to report
      information about the game.  Default: False
    - TopicFormat: The format of the topic. Variables are:
       - %motd: The message of the day.
       - %gametype, %map, %numplayers, %maxplayers should be fairly obvious.
      This can be changed with the !topicformat command.
    - Motd: The message of the day for the topic.  This can be changed with
      the !motd command.

------------------------------------------------------------------------------
 Commands
------------------------------------------------------------------------------
 * Issue !commands to see a list of commands.
 * Issue !help <command> to see a description of a command.
 * The ! prefix can be changed - see CommandPrefix in Other Settings above.

------------------------------------------------------------------------------
 Thanks
------------------------------------------------------------------------------
 * Wormbo, for feedback and also for the Wormbot UT2004 IRC reporter bot,
   from which I have gotten a few ideas.
 * Haarg, for running FragBU with this bot.
 * Defeat, for being awesome.  <4
