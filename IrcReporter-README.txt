UT3 IRC
http://ner.mine.nu:3080/ut3irc/
Authors: Nereid, Zer0

-----------------------------------------------------------------------------
IRC repoter bot

Installation:
 * .u files go in UTGame\Published\CookedPC (in your UT3 user directory which
   is typically My Documents\My Games\Unreal Tournament 3).
 * .ini files go in UTGame\Config.

Configuration:
 * Edit the [IrcReporter.IrcReporter] section of UTIrcReporter.ini
 * Most of the settings are fairly obvious from their name.
 * Reporting settings:
    - MessageTypes: A list of types of game event messages and whether they
      should be reported to IRC. The possible types are:
       - GameStatus: Game information on a new map.
       - Startup: The match started.
       - Kill: Death messages.
       - FirstBlood: A player draws first blood.
       - Spree: Killing sprees.
       - CarriedObject: Flag events in CTF and VCTF, and orb events in
         Warfare.
       - TeamScore: A team scores (except in TDM).
       - Overtime: The game timer runs out.
       - Connected: A player connected to the server.
       - Disconnected: A player disconnected from the server.
       - TeamChange: A player changes teams, or changes spectator status.
       - Onslaught: Warfare power node messages.
       - OnslaughtCore: Warfare power core messages.
       - MatchOver: The game ends.
       - RoundOver: The round ends in, for example, Warfare.
 * Chat settings:
    - bEnableChat: If set to True, the bot will relay chat messages between
      IRC and the game.
    - bEnableTwoWayChat: This setting determines whether the bot will relay
      chat from IRC to the game.
    - bRequireSayCommand: If set, IRC users must use !say to send chat to the
      game.
    - ChatChannel: If set, the bot will relay chat to this channel.  Normally,
      it would relay chat to the ReporterChannel.
 * Throttle settings:
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
 * Topic settings:
    - bSetTopic: If true, the bot will modify the channel topic to report
      information about the game.  Default: True
    - TopicFormat: The format of the topic. Variables are:
       - %motd: The message of the day.
       - %gametype, %map, %numplayers, %maxplayers should be fairly obvious.
      This can be changed with the !topicformat command.
    - Motd: The message of the day for the topic.  This can be changed with
      the !motd command.
 * Other settings:
    - AdminHostmasks: A list of hostmasks for users that should be allowed to
      execute admin commands on the bot.
    - CommandPrefix: The bot has a number of commands, such as !status and
      !scores.  This setting lets you change the command prefix.
    - LogLevel: The minimum level of importants required for messages to be
      logged to the log file.  Possible values: LL_Debug, LL_Notice,
      LL_Warning, LL_Error.  Default is LL_Warning.  If you are having a
      problem with the bot, set this to LL_Debug to get (a lot of) debugging
      information.

Commands:
 * Issue !commands to see a list of commands, and !help <command> to see a
   description of a command.

Thanks to:
 * Wormbo, for feedback and also for the Wormbot UT2004 IRC reporter bot,
   from which I have gotten a few ideas.
 * Haarg, for running FragBU with this bot.
 * Defeat, for being awesome.  <4
