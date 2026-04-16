# Defrager - RTS Module
Defrag tools - Töredezettség mentesítő megoldások


Ez a modul az RTS (Real Time System) keretrendszer része, célja a lemezkarbantartás teljes automatizálása és a Windows 7-11 közötti kompatibilitás optimalizálása.

#Funkciók
- W10 Engine Port: Ha az /Apps mappába másolod a Windows 10 defrag.exe fájlját, a rendszer automatikusan lecseréli a régebbi verziót a hatékonyabb W10-es motorra.
- Intelligens Ciklusok: 1x indítással 3 körös Defrag + Scandisk láncot futtat le, minden kör után automatikus újraindítással és chkdsk ütemezéssel.
- GUI Fix: Megjavítja az el nem induló grafikus felületet a szolgáltatások és regisztrációs utak helyreállításával.
- Naplózás: Minden eseményt a /LOG mappába ment, így az újraindítások után is követhető a folyamat.


# Telepítés és használat
- Másold a defrag.exe-t és defragres.dll-t (W10-ből) az /Apps mappába (opcionális).
- Indítsd el a /Scripts/RTS_Defrag_Launcher.bat fájlt Rendszergazdaként.
- Válaszd az 1-es opciót a teljes mélytisztításhoz.


#Figyelmeztetés
A mélytisztítás (1-es opció) többszöri újraindítással jár! Ments el minden munkát futtatás előtt.

