# PRICE-SCHEDULER.BAT

Skripti price-scheduler.bat tarkistaa s‰hkˆn hinnan palvelusta spot-hinta.fi. Jos hinta on maksimissaan %PriceThreshold% k‰ynnistet‰‰n ohjelma %ProgramToRun%. Jos hinta on alle %PriceThreshold% sammutetaan prosessi %ProcessName%. K‰yt‰ hinnassa maksimissaan nelj‰‰ desimaalia. K‰ynnistykset ja sammutukset kirjoitetaan logitiedostoon %LogFile%. 

Versiosta 0.3 eteenp‰in skripti tukee myˆs rank-arvoa. Rank kertoo kuinka halpa tunnin hinta on verrattuna muihin vuorokauden tunteihin. Rank 1 on halvin tunti, rank 2 seuraavaksi halvin jne. Jos rank on maksimissaan %RankThreshold%, k‰ynnistet‰‰n ohjelma. Muutoin prosessi sammutetaan ellei hintaehto t‰yty. 

Skripti k‰ytt‰‰ hintojen noutamiseen Wget-ohjelmaa (https://eternallybored.org/misc/wget/). Lataa wget.exe samaan kansioon skriptin kanssa tai varmista, ett‰ wget toimii komentokehoitteesta. Batch-skriptit eiv‰t tue laskutoimituksissa desimaalilukuja, joten laskutoimituksiin k‰ytet‰‰ ohjelmaa Command line calculator (https://cmdlinecalc.sourceforge.io/). Kopioi laskurin calc.exe samaan kansioon skriptin kanssa v‰ltt‰‰ksesi ongelmat, koska Windowsin oma laskuri on myˆs calc.exe.

Ohjelman k‰ynniss‰olo tarkistetaan 30 sekunnin v‰lein. Nykyisen p‰iv‰n ja seuraavan p‰iv‰n, jos saatavilla, hintatiedot p‰ivitet‰‰n tunnin v‰lein tiedostoon TodayAndDayforward.json. Jos Json-tiedosto p‰‰see vanhenemaan eik‰ palvelu spot-hinta.fi vastaa, kysyt‰‰n hinta palvelusta porssisahko.net.

Apuskripti hidden-price-scheduler.bat k‰ynnist‰‰ skriptin price-scheduler.bat piilotettuun ikkunaan, jolloin skripti toimii ik‰‰n kuin Windowsin taustapalvelu. T‰h‰n k‰ytet‰‰n ohjelmaa CMDH (https://web.archive.org/web/20190915154950/http://www.gate2.net:80/tools/cmdh/cmdh.html).

Huom! T‰m‰ skripti ei ole k‰ynyt l‰pi huolellista testausta eik‰ sit‰ pid‰ k‰ytt‰‰ mihink‰‰n vaativaan k‰yttˆˆn. 

## Muutoksia

Versio 0.1: Palvelu spot-hinta.fi ei hetkellisesti vastannut, joten varapalveluksi on lis‰tty porssisahko.net.

Versio 0.2: Hinnan tarkistaminen on koodattu uudelleen.

Versio 0.3: Lis‰tty rank.

Versio 0.4: Pieni‰ muutoksia mm. logitukseen.
