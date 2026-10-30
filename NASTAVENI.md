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
Dostane profil bratra (300 znaku denne, 3000 tydne). Pokud dosud nebyla
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

Bezny profil ma denni cil 250 znaku, bratruv profil 300 znaku.
Tydenni cil je vzdy 10 * denni cil.
Od verze 16 ma bratruv profil dve odlozeni denne, bezny profil nadale tri.
Pri uprave limitu se meni pouze `DEFAULT_DAILY_GOAL` a `BROTHER_DAILY_GOAL`.

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

## 5. Pocitani spravnych znaku

Od verze 16 se porovnava cely napsany text s celym zadanim pomoci globalniho
zarovnani s nejmensim poctem uprav. Pri stejne vzdalenosti se uprednostni
vice presne shodnych znaku. Zapocitaji se jen shodne znaky vcetne mezer,
rozlisuji se mala a velka pismena. Vynechane casti, preklepy nebo chybejici
mezery neznehodnoti spravne pokracovani. Nadbytecne znaky se nepricitaji.
Konce radku a tabulatory se pri porovnani povazuji za mezeru.
Puvodni ulozene vysledky se pri aktualizaci automaticky neprepisuji.
