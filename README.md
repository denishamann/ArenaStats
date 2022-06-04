# ArenaStats - TBC

## Screenshot

![mainview](https://user-images.githubusercontent.com/15311371/172021323-7586d64c-5d2d-4fcb-b2f8-375cf8e33f1f.png)

**Classic BCC addon for arena history and statistics**

_[Report issues here](https://github.com/denishamann/ArenaStatsTBC/issues)._

ArenaStats - TBC tries to record every arena joined and compiles statistics.
Heavily inspired by [Battlegrounds Historian TBC](https://www.curseforge.com/wow/addons/bghistorian-tbc), which doesn't seem to release arena support for now.

Responds to console with **/arenastats** or **/as** and a minimap button.

## Features

- **Record** played arena statistics
- Display summarised **arena history** in a table
- Exportable data into **csv** format (which can easily be used for advanced statistics)

## Visualizer

You can paste your export string in the _[ArenaStatsTBC Visualizer](https://denishamann.github.io/arena-stats-tbc-visualizer/)_ tool.
You can contribute to improve the visulizer tool _[here](https://github.com/denishamann/arena-stats-tbc-visualizer)_. 

## Todo

### Common

- ~~Add a setting to disable the recording of skirmishes (suggested by @TheDonkeyPower)~~ Done! (added filters on ranked/skirm)
- ~~Show who won a skirmish~~ Done!
- Detect spec

### In game gui:
- ~~Add tooltip on hover on class to display name/race~~ Done!
- ~~Filter on bracker type~~ Done!

### Csv:
- ~~Add csv column for bracket type~~ The _[ArenaStatsTBC Visualizer](https://denishamann.github.io/arena-stats-tbc-visualizer/)_ is now available!
- Provide a csv sheet with prepared graphs in which we can paste our data


## Known issues

- If you quit the arena and there is still someone of your team alive, the arena won't be recorded (stay until the scoreboard shows or quit only if you are the last one alive).
- ~~Sometimes player names are not recorded~~ Fixed
- ~~Sometimes data is not correctly reset between games and there are ghost players added to the arena or timers are wrong~~ Fixed
- If a player gets disconnected at the end of the arena it records twice the arena match (reported by @Lilianos)

## List of fields available at CSV export for each Arena match
isRanked, startTime, endTime, zoneId, duration, teamName, teamPlayerName1, teamPlayerName2, teamPlayerName3, teamPlayerName4, teamPlayerName5, teamPlayerClass1, teamPlayerClass2, teamPlayerClass3, teamPlayerClass4, teamPlayerClass5, teamPlayerRace1, teamPlayerRace2, teamPlayerRace3, teamPlayerRace4, teamPlayerRace5, oldTeamRating, newTeamRating, diffRating, mmr, enemyOldTeamRating, enemyNewTeamRating, enemyDiffRating, enemyMmr, enemyTeamName, enemyPlayerName1, enemyPlayerName2, enemyPlayerName3, enemyPlayerName4, enemyPlayerName5, enemyPlayerClass1, enemyPlayerClass2, enemyPlayerClass3, enemyPlayerClass4, enemyPlayerClass5, enemyPlayerRace1, enemyPlayerRace2, enemyPlayerRace3, enemyPlayerRace4, enemyPlayerRace5, enemyFaction

## Contribution

You can help this project by adding [translations](https://www.curseforge.com/wow/addons/arenastats-tbc/localization) and [reporting issues](https://github.com/denishamann/ArenaStatsTBC/issues).
