# Defrager - Intelligens Lemezkarbantartó és RTS Module
Defrag tools - Töredezettség mentesítő megoldások


Ez a modul az RTS (Real Time System) keretrendszer része, célja a lemezkarbantartás teljes automatizálása és a Windows 7-11 közötti kompatibilitás optimalizálása.


## Főbb jellemzők
- **S.M.A.R.T. Védelem:** A folyamat el sem indul, ha a merevlemez fizikai meghibásodást jósol, így elkerülhető az adatvesztés.
- **Biztonsági Mentés:** Minden futás előtt menti a Registry SYSTEM ágát és a `hosts` fájlt a `..\LOG\Recovery` mappába.
- **W10 Motor Portolás:** Ha a Windows 10-ből származó `defrag.exe` és `defragres.dll` fájlokat az `\Apps` mappába helyezed, a script automatikusan frissíti a rendszert ezekre a hatékonyabb verziókra.
- **Ciklus-vezérlés:** Az "Alapos" módban 3 alkalommal fut le a töredezettségmentesítés, közte automatikus `chkdsk` (Scandisk) vizsgálatokkal és újraindításokkal.
- **GUI Javítás:** Képes helyreállítani a Windows beépített grafikus felületét, ha az nem indulna el.


## Használat
1. Futtasd a `Scripts\Defrag_Launcher.bat` fájlt **Rendszergazdaként**.
2. Válaszd az 1-es opciót a teljes ciklushoz.
3. A gép többször újra fog indulni, a folyamat végén a naplók a `\LOG` mappában lesznek elérhetőek.


#Funkciók
- W10 Engine Port: Ha az /Apps mappába másolod a Windows 10 defrag.exe fájlját, a rendszer automatikusan lecseréli a régebbi verziót a hatékonyabb W10-es motorra.
- Intelligens Ciklusok: 1x indítással 3 körös Defrag + Scandisk láncot futtat le, minden kör után automatikus újraindítással és chkdsk ütemezéssel.
- GUI Fix: Megjavítja az el nem induló grafikus felületet a szolgáltatások és regisztrációs utak helyreállításával.
- Naplózás: Minden eseményt a /LOG mappába ment, így az újraindítások után is követhető a folyamat.


# Telepítés és használat
- Másold a defrag.exe-t és defragres.dll-t (W10-ből) az /Apps mappába (opcionális).
- Indítsd el a /Scripts/Defrag_Launcher.bat fájlt Rendszergazdaként.
- Válaszd az 1-es opciót a teljes mélytisztításhoz.


#Figyelmeztetés
A mélytisztítás (1-es opció) többszöri újraindítással jár! Ments el minden munkát futtatás előtt.


## Repó struktúra
- `\Apps`: Ide másold a frissíteni kívánt defrag binárisokat.
- `\Scripts`: A vezérlő scriptek helye.
- `\LOG`: Naplófájlok és biztonsági mentések helye.


#Ez a modul az **RTS keretrendszer** része, melyet régebbi (Win7) és modern (Win10/11) rendszerek mély-karbantartására terveztek.
----------------------------

