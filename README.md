# ArenaStats - TBC

**Classic BCC addon for arena history and statistics**

_[Report issues here](https://github.com/denishamann/ArenaStatsTBC/issues)._

ArenaStats - TBC tries to record every arena joined and compiles statistics.
Heavily inspired by [Battlegrounds Historian TBC](https://www.curseforge.com/wow/addons/bghistorian-tbc), which doesn't seem to release arena support for now.

Responds to console with **/arenastats** and a minimap button.

## Features

- **Record** played arena statistics
- Display summarised **arena history** in a table
- Exportable data into **csv** format (which can easily be used for advanced statistics)

## List of fields available at CSV export for each Arena match

- isRanked
- startTime
- endTime
- zoneId
- duration
- teamName
- teamPlayerName1
- teamPlayerName2
- teamPlayerName3
- teamPlayerName4
- teamPlayerName5
- teamPlayerClass1
- teamPlayerClass2
- teamPlayerClass3
- teamPlayerClass4
- teamPlayerClass5
- teamPlayerRace1
- teamPlayerRace2
- teamPlayerRace3
- teamPlayerRace4
- teamPlayerRace5
- oldTeamRating
- newTeamRating
- diffRating
- mmr
- enemyOldTeamRating
- enemyNewTeamRating
- enemyDiffRating
- enemyMmr
- enemyTeamName
- enemyPlayerName1
- enemyPlayerName2
- enemyPlayerName3
- enemyPlayerName4
- enemyPlayerName5
- enemyPlayerClass1
- enemyPlayerClass2
- enemyPlayerClass3
- enemyPlayerClass4
- enemyPlayerClass5
- enemyPlayerRace1
- enemyPlayerRace2
- enemyPlayerRace3
- enemyPlayerRace4
- enemyPlayerRace5
- enemyFaction

## Todo

### Common

- Detect spec

### In game gui:
- Add tooltip on hover on class to display name/race
- Filter on bracker type

### Csv:
- Add csv column for bracket type
- Provide a csv sheet with prepared graphs in which we can paste our data


## Known issues

- If you quit the arena and there is still someone of your team alive, the arena won't be recorded (stay until the scoreboard shows or be quit only if you are the last one alive).
- Sometimes player names are not recorded
- Sometimes data is not correctly reset between games and there are ghost players added to the arena or timers are wrong
- If a player gets disconnected at the end of the arena it records twice the arena match (reported by @Lilianos)


## Contribution

You can help this project by adding [translations](https://www.curseforge.com/wow/addons/arenastats-tbc/localization) and [reporting issues](https://github.com/denishamann/ArenaStatsTBC/issues).