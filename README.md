# AntiBhopCheat

Detect any kinds of bhop cheat, limit bhop of flagged player or kick it, and send detailleds logs on Discord.

![Preview](https://i.imgur.com/T2NYkTc.png)

## Advisor Requirement

For **1.5 and above** you need: https://github.com/sbpp/sourcebans-pp/pull/763/files

## Usage
```
sm_stats <target>
sm_streak <target>
```

## Config
```
sm_antibhopcheat_detection_sound <value> Emit a beep sound when someone gets flagged [0 = disabled, 1 = enabled]
sm_antibhopcheat_kick_hack <value> Automaticly Kick if a player is flagged for HACK? [0 = disabled, 1 = enabled]
sm_antibhopcheat_count_bots <value> Should we count bots as players ?[0 = No, 1 = Yes]
```
