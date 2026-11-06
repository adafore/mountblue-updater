# Nastaveni profilu a sdileni zaznamu

## 1. Sdilena slozka

Na bratrove PC vytvorte v OneDrivu slozku `MountBlue-zaznamy`.
V OneDrivu zvolte Sdilet, Konkretni lide a pozvete svuj Microsoft ucet.
Na svem PC pozvanku prijmete. Zaznamy lze otevrit ve webovem OneDrivu
v casti Sdilene. Pro synchronizaci do Pruzkumnika pouzijte Pridat zastupce
do Moje soubory, pokud je tato moznost dostupna.

Pro pristup pouze pres web staci opravneni ke cteni. Pridani zastupce
muze vyzadovat opravneni k upravam. Verejny odkaz neni potreba.

## 2. Automaticke nastaveni znameho bratrova PC

Od verze 14 se znamy bratruv ucet a pocitac nastavi automaticky pri startu.
Dostane profil bratra (400 znaku denne, 4000 tydne). Pokud dosud nebyla
vybrana sdilena slozka, pouzije se `OneDrive\Attachments\OneNote` v jeho
uzivatelske slozce Windows. Jiz vybrana slozka se neprepisuje.

Pro parovani se pouziva SHA-256 otisk kombinace pocitace a uctu Windows.
Puvodni identifikatory nejsou ve verejnem zdrojovem kodu. Ostatni pocitace
a ucty zustanou beze zmeny, ani samotne zkopirovani ID instalace nestaci.
ID instalace, rozepsany postup a dosavadni zaznamy zustanou zachovany.

Automaticke nastaveni se provede pouze jednou. Pozdejsi rucni zmena profilu,
slozky nebo vypnuti sdileni se pri dalsim startu nevrati zpet.
Pokud slozka zatim neni dostupna, zaznamy cekaji mistne na jeji zpristupneni;
program nevytvari nahradni slozku a nemeni opravneni OneDrivu.

### Rucni nastaveni (jen pokud je potreba)

1. Soubor `Nastaveni.cmd` umistete vedle aktualniho `PovinePsani.ahk`.
2. Spustte `Nastaveni.cmd`. Zadejte heslo `953`.
3. Zaskrtnete, ze tento ucet a pocitac patri bratrovi.
4. Tlacitkem Vybrat vyberte skutecnou mistni slozku v bratrove OneDrivu.
5. Ulozte nastaveni. Program se znovu spusti bez nastavovaciho okna.

Vyber slozky ani zmena profilu nejsou soucasti bezneho panelu.
Alternativne lze skript spustit s argumentem `--setup`.

Bezny profil ma denni cil 300 znaku (3000 tydne), bratruv profil 400 znaku (4000 tydne).
Tydenni cil je vzdy 10 * denni cil.
Bratruv profil ma 2 odlozeni denne, bezny profil nadale 3 odlozeni.
K dispozici je take tlacitko rychleho odlozeni na 10 sekund.
Pri uprave limitu se meni `DEFAULT_DAILY_GOAL`, `BROTHER_DAILY_GOAL`, `DEFAULT_POSTPONE_COUNT` a `BROTHER_POSTPONE_COUNT`.

Profil je navazany na jedinecne ID instalace, ucet Windows a pocitac.
Ulozen je v `%AppData%\MountBlueEnforcer\device.ini` a aktualizace jej zachovavaji.
Zkopirovani tohoto souboru na jiny ucet nebo pocitac neprenese bratrovsky profil
ani nastaveni sdileni. Novy uzivatel automaticky zacina s beznym profilem.

## 3. Otevreni zaznamu

V nasdilene slozce jsou podslozky `ID-instalace\datum`.
ID je viditelne v oddelenem nastavovacim okne.

- `.txt`: citelny prehled zadani, odevzdanych i rozpracovanych pokusu a oprav.
- `.jsonl`: podrobne udalosti vcetne puvodne napsanych a smazanych znaku.

Zaznamenava se pouze cviceni v aktivnim okne MountBlue, nikoliv psani v jinych
aplikacich nebo v heslovych dialozich. Zaznamy se prubezne ukladaji mistne
do `%AppData%\MountBlueEnforcer\logs`. Puvodni zaznamy z doby pred touto verzi
nelze dodatecne zrekonstruovat.

Program kopiruje zaznamy do vybrane slozky; prenos mezi pocitaci zajistuje OneDrive.
Pri nedostupne slozce zustanou zaznamy ulozene mistne a zkusi se prenest znovu.
Pokud OneDrive zobrazuje chybu nebo neni prihlaseny, je potreba ji vyresit
v samotnem OneDrivu. K otevreni se pouziva vlastni Microsoft ucet prijemce,
zadne prihlasovaci udaje se nevkladaji do skriptu ani do GitHubu.

## 4. Ovlivneni ovladani

Bezny vzhled panelu, Odlozit, potvrzovaci tlacitka i Odemknout PC zustavaji zachovany.
Kliknuti na Odemknout funguje pres celou plochu i okraj tlacitka.
Hlidac pri potvrzovani a odemykani neprepina focus zpet do MountBlue.
Vstup se pri startu neblokuje, dokud MountBlue neni skutecne aktivni.
Pri neuspesnem otevreni se nabidne opakovani a PC zustava ovladatelne.
Od verze 15 se docasne odmitnuti prepnuti do beziciho MountBlue nepovazuje
za chybu spusteni. Hlidac prepnuti opakuje automaticky a do te doby neblokuje
systemove zkratky. Vlastni dialog MountBlue se pocita jako otevrene okno,
ale nikdy se nemaximalizuje. Potvrzeni, odlozeni a odemykani se neprerusuji.
Skutecna chyba startu rozlisuje chybejici soubor, odmitnute spusteni,
nedostupne okno a odmitnute prepnuti. Duvod je i v udalosti `startup_error`
v mistnim zaznamu; docasne opakovani focusu ma udalost `focus_retry`.
Pause/Break nadale slouzi pro znovunacteni mimo odlozeni.

Pri zamcenem cviceni je hlavni panel Windows prekryty (zadne nahledy oken,
nic se nezavira) a okno Obraz v obraze se zavre. Vsechny ne-systemove aplikace
(hry, Discord, Roblox, Steam, webove prohlizece, prehravace videa atd.) jsou
po dobu zamceni udrzovany minimalizovane, takze je nelze hrat ani sledovat
na dalsim monitoru nebo vedle Spotify. Povoleny zustavaji pouze veci potrebne
pro program (MountBlue, dialog na heslo 953, panel), Spotify, nastroje pro snimani
(PowerToys, Vystrizky) a systemove utility (Nastaveni Windows, Pruzkumnik souboru).
Pod zelenym tlacitkem Spotify je k dispozici tlacitko "Zastavit to, co delas (10 s)".
Pri 1. spusteni i po kazdem normalnim odlozeni se zobrazi a po stisku odemkne cele PC
na 10 sekund (vstup, panely i okna), presne jako pri odlozeni, aby bylo mozne zastavit
video, ulozit rozdelanou praci nebo ukoncit aktivitu. Po 10 sekundach se cviceni opet
uzamkne a tlacitko se skryje az do dalsiho normalniho odlozeni. Spotify se ovlada
vlastnim zelenym tlacitkem v panelu nebo zkratkou Ctrl+Alt+Insert.



## 5. Pocitani spravnych znaku

Od verze 17 se globalne zarovnavaji slova z celeho pokusu a celeho zadani.
Uvnitre dvojice slov se hledaji presne shodne znaky, ale dvojice muze dostat
body jen pri shode alespon 60 % znaku delsiho slova. Nejde o slovnik ani
kontrolu vyznamu; porovnava se podobnost s konkretnim zadanim.

Vynechane casti neznehodnoti spravne pokracovani. Chybejici nebo nadbytecne
mezery se resi spojenim az tri sousednich slov. U nedopsaneho posledniho
slova se overuje podobnost se zacatkem ocekavaneho slova, takze neni nutne
dokoncit cele slovo nebo cele cviceni. Spravne casti uznaneho slova se pocitaji
i pri nekolika preklepech; nahodne shody v odmitnutych slovech nikoli.

Mezery se pocitaji jen u uznanych slov, nejvyse tolikrat, kolik jich obsahuje
zadani i pokus. Rozlisuji se mala a velka pismena. Nadbytecne znaky se
nepricitaji. Konce radku a tabulatory se pri porovnani povazuji za mezeru.
Puvodni ulozene vysledky se pri aktualizaci automaticky neprepisuji.
