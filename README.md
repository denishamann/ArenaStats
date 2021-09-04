# ArenaStats - TBC

**Classic BCC addon for arena history and statistics**

_This addon is currently a raw alpha, expect issues you may want to [report](https://github.com/denishamann/ArenaStatsTBC/issues)._

ArenaStats - TBC tries to record every arena joined and compiles statistics.
Heavily inspired by [Battlegrounds Historian TBC](https://www.curseforge.com/wow/addons/bghistorian-tbc), which doesn't seem to release arena support for now.

Responds to console with **/arenastats** and a minimap button.

## Features

Mostly working parts :

- Record played arena statistics
- Display summarised arena history in a table
- Exportable data into csv format (which can easily be used for advanced statistics)

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

## Known issues

- If you quit the arena and there is still someone of your team alive, the arena won't be recorded (stay until the scoreboard shows or be quit only if you are the last one alive).

## Contribution

You can help this project by adding [translations](https://www.curseforge.com/wow/addons/arenastats-tbc/localization) and [reporting issues](https://github.com/denishamann/ArenaStatsTBC/issues).