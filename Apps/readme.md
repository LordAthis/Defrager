# [HU] Külső motor és Kompatibilitási Útmutató
Ez a mappa a modernebb lemezkarbantartó binárisok befogadására szolgál. A keretrendszer része, de önállóan is használható.

### Telepítés:
Másold ide a `defrag.exe`, `defragres.dll` és `dfrgui.exe` fájlokat. 
A script **Verzió-ellenőrzést (File Version Check)** végez: csak akkor frissít, ha az itt lévő fájl újabb a rendszerénél.
A script automatikusan elhelyezi őket a `System32` és a megfelelő nyelvi mappába (pl. `hu-HU`) is.

### ⚠️ Fontos Figyelmeztetés:
**Win 11 -> Win 10:** Nem javasolt! A Windows 11 motorja olyan kernel-hívásokat használhat, amelyek régebbi Windows 10 verziókon (pl. LTSB 1607) kékhalált (BSOD) okozhatnak.
**Nyelvi támogatás:** Ha nem magyar/angol a rendszered, hozz létre egy mappát a nyelvi kódoddal (pl. `fr-FR`) és tedd bele a fájlokat.

### Kompatibilitási Mátrix:


| Forrás OS | Cél OS | Státusz | Megjegyzés |
| :--- | :--- | :--- | :--- |
| Win 11 | Win 10 | ⚠️ VIGYÁZAT | Kékhalál kockázat régebbi buildeken! |
| Win 10 | Win 7 / 8 | ✅ AJÁNLOTT | SSD-TRIM támogatás és stabilitás. |
| Win 7 | Win XP | ❌ NEM | Az XP nem támogatja az újabb API-kat. |
| Win 98 | Win 95 | ✅ IGEN | Gyorsabb algoritmus. |

---

# [EN] External Engine & Compatibility Guide
This folder is for hosting modern disk maintenance binaries. Part of the framework, but works standalone.

### Installation:
Copy `defrag.exe`, `defragres.dll`, and `dfrgui.exe` here. 
The script performs a **File Version Check** and only updates if these files are newer than the system's.
The script automatically places them in `System32` and the correct language folder (e.g., `en-US`).

### ⚠️ Critical Warning:
**Win 11 -> Win 10:** Not recommended! The Windows 11 engine may use kernel calls that cause a Blue Screen (BSOD) on older Windows 10 builds.


---

# [FR] Moteur externe et Guide de compatibilité
Ce dossier accueille des binaires de maintenance de disque plus modernes.

### Installation:
Copiez `defrag.exe`, `defragres.dll` et `dfrgui.exe` ici. Le script les placera automatiquement dans `System32` et `System32\fr-FR`.

---

# [DE] Externe Engine & Kompatibilitätshandbuch
Dieser Ordner dient zur Aufnahme modernerer Festplatten-Wartungsbinärdateien.

### Installation:
Kopieren Sie `defrag.exe`, `defragres.dll` und `dfrgui.exe` hierher. Das Skript platziert sie automatisch in `System32` und `System32\de-DE`.
