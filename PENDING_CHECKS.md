# ⚠️ Zaległe testy po migracji Hyprlanda na Lua (dodane 2026-09-26)

**Dla agenta:** ten plik jest importowany do `CLAUDE.md` — jeśli go widzisz, zadania poniżej są wciąż otwarte.
Na starcie sesji sprawdź **warunek** każdego zadania. Gdy jest spełniony — zaproponuj użytkownikowi test
(nie uruchamiaj pomiarów bez jego zgody, patrz niżej). Kontekst: `~/Projects/hyprland-lua-migration/README.md`.

---

## Zadanie 1 — porównanie pamięci (RAM) po kilku godzinach pracy

**Warunek:** sesja Hyprlanda działa ≥ 4 h: `ps -o etimes= -p "$(pgrep -x Hyprland)"` ≥ 14400.

**Dlaczego:** pomiar bazowy przed migracją (hyprlang) był zrobiony po wielu godzinach pracy, z częścią pamięci
w swapie; pomiar po migracji — 25 min po reboocie. RSS nieporównywalne; CPU już porównane (bez różnic).

**Procedura:**
1. ⏸ **Najpierw poinformuj użytkownika i poczekaj** — zamyka aplikacje (zostawia btop + terminal z Claude).
   Nie uruchamiaj pomiaru bez jego potwierdzenia.
2. `~/Projects/hyprland-lua-migration/tools/measure-idle.sh 120` (≈2 min, w tle).
3. Dodatkowo zapisz swap per proces: `grep -E 'VmRSS|VmSwap' /proc/$(pgrep -xo <proc>)/status`
   dla Hyprland, waybar, swaync, hyprpaper — bez tego RSS znów może być nieporównywalny.
4. Porównaj z `~/Projects/hyprland-lua-migration/plan/pomiar-bazowy.md` (tabele „Wyniki” i „Po migracji”).
5. Pokaż wyniki użytkownikowi — **decyzję (akceptujemy / optymalizujemy) podejmuje on**. Progi to ostrzeżenia.
6. Dopisz wyniki do `plan/pomiar-bazowy.md` (nowa sekcja z datą i uptime).

**Pozytywny wynik** = użytkownik zaakceptował → usuń Zadanie 1 z tego pliku.

---

## Zadanie 2 — szybki test po aktualizacji do Hyprland 0.57+

**Warunek:** `pacman -Q hyprland` pokazuje wersję ≥ 0.57 (0.57 usuwa obsługę `hyprland.conf`; config jest już w Lua).

**Procedura (automatycznie):**
1. `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua` → `config ok`
2. `hyprctl -j status` → `"configProvider": "lua"`; `hyprctl configerrors` → puste; `hyprctl binds -j | jq length` → 74
3. GPU: w `$XDG_RUNTIME_DIR/hypr/*/hyprland.log` linia `gpu /dev/dri/card2 becomes primary drm` (Intel)
4. Autostart po 1 instancji: nm-applet, waybar, hyprpaper, blueman-applet, hypridle, udiskie, swaync;
   `systemctl --user is-active hyprpolkitagent` → active
5. Przejrzyj changelog 0.57 pod kątem zmian w API Lua (`hl.*`) i tabelę różnic
   `~/Projects/hyprland-lua-migration/research/01-lua-api-i-skladnia.md` §7 (np. `dampening` → `damping`).

**Procedura (ręcznie — poproś użytkownika):** kilka skrótów (SUPER+Return, workspace'y, media),
SUPER + prawy przycisk myszy (resize), SUPER+W zmiana tapety → kolory ramek, uśpienie i wybudzenie z HDMI.

**Pozytywny wynik** = wszystko OK → usuń Zadanie 2 z tego pliku. Przy błędzie: nie usuwaj, opisz problem
w `~/Projects/hyprland-lua-migration/plan/faza-A-wyniki-testow.md`. Awaryjny downgrade: cache pacmana
nie trzyma starych hypr* (sprawdzone 2026-09-26) → Arch Linux Archive
(`https://archive.archlinux.org/packages/h/hyprland/`, cały zestaw hypr* + aquamarine w zgodnych wersjach,
`pacman -U …`). Uwaga: `backup/restore.sh` przywraca config `.conf`, który na 0.57 **nie działa**.

---

## Sprzątanie (gdy oba zadania usunięte)

1. Usuń ten plik: `~/arch-hyprland-ajmag/PENDING_CHECKS.md`.
2. Usuń linię importu `@…PENDING_CHECKS.md` z:
   - `~/arch-hyprland-ajmag/CLAUDE.md`
   - `~/.config/CLAUDE.md`
   - `~/Projects/hyprland-lua-migration/CLAUDE.md`
3. Commit w `~/arch-hyprland-ajmag` na osobnej gałęzi + PR do `main` (tak pracuje użytkownik).
4. Odnotuj zamknięcie w `~/Projects/hyprland-lua-migration/README.md` (sekcja „Status”).
