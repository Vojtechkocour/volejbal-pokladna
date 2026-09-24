# Volejbalová pokladna

Docházka na volejbalové tréninky s předplatným. Víc správců, všichni vidí stejná data živě.

- **Technologie:** jeden HTML soubor (bez buildu) + Supabase (databáze, přihlášení e-mailem, živé změny)
- **Aplikace:** https://vojtechkocour.github.io/volejbal-pokladna/
- **Repozitář:** https://github.com/Vojtechkocour/volejbal-pokladna (veřejný – nic citlivého v něm není)
- **Nasazení:** push do `main` → GitHub Pages se za 1–2 minuty aktualizuje
- **Stav:** 🚧 nasazeno na GitHub Pages + Supabase (2026-09-24), čeká na první ostré přihlášení
- **Původní verze (Claude artefakt):** `index-artifact.html`, https://claude.ai/artifact/VjPTvfvwMMbsLNVuiZ6K1V

## Funkce
- Trénink: výběr data, hromadné označení přítomných, typ (normální / zdarma / zrušený), poznámka
- Hráči: přidání, hledání, řazení, archivace
- Karta hráče: zůstatek, platby, historie s průběžným zůstatkem
- Přehled: **pokladna celkem** (skutečný stav peněz zadávaný ručně k datu, s historií – nezávislé na předplatném), kredit hráčů, dluhy, počet tréninků, průměrná účast
- Nastavení: ceník s platností od data, výchozí platba, dny tréninků, účet / odhlášení

## Přístup
- Jen pro správce. Přihlášení **jménem a heslem**, žádné e-maily se neposílají.
- Jméno `tomas` se v Supabase ukládá jako `tomas@volejbal.example` (rezervovaná doména, nic se nedoručí). Kdo zadá skutečný e-mail (se `@`), použije se tak, jak je.
- `members.role = 'admin'` → čte i upravuje, `'viewer'` → jen čte, kdokoli jiný → nic.
- Pravidla hlídá databáze (row level security v `supabase/schema.sql`), ne aplikace.
- Veřejný publishable key v `index.html` je v pořádku. **Secret / service_role key do kódu nikdy.**
- Knihovna Supabase i písma jsou uložené v `vendor/` – žádné cizí CDN ani Google Fonts.

### Přidání správce
1. Supabase → *Authentication → Users → Add user → Create new user*:
   e-mail `jmeno@volejbal.example`, silné náhodné heslo (min. 12 znaků), zaškrtnout **Auto Confirm User**.
2. Supabase → *SQL Editor*:
   ```sql
   insert into members (email, role) values ('jmeno@volejbal.example', 'admin'); -- nebo 'viewer'
   ```
3. Jméno (`jmeno`) a heslo předat osobně.

**Zapomenuté heslo:** *Users* → uživatel → nastavit nové heslo.
**Odebrání:** `delete from members where email = '...';` – přístup k datům končí okamžitě. Pak smazat i uživatele v *Users*.

## Soubory
- `index.html` – aplikace; nahoře v `<script>` jsou `SUPABASE_URL` a `SUPABASE_KEY`
- `supabase/schema.sql` – tabulky, přístupová pravidla, realtime (spustit jednou)
- `private/import.sql` – správci + data přenesená z artefaktu (**není v gitu**, obsahuje jména a e-maily)

## Nastavení Supabase (jednou)
1. Založit projekt (region Frankfurt).
2. *SQL Editor* → spustit `supabase/schema.sql`, pak `private/import.sql`.
3. *Authentication → Sign In / Providers*: vypnout **Allow new users to sign up**; u Email nechat zapnuté, **Minimum password length = 12**.
4. *Authentication → URL Configuration*: **Site URL** = adresa na GitHub Pages.
5. Založit správce (viz výše).

## Datový model
Každá tabulka má `id text`, `data jsonb`, `updated_at`:
- `players`: name, active, createdAt
- `trainings` (id = `YYYY-MM-DD`): date, status (normal|free|cancelled), attendees[], note
- `payments`: playerId, amount, date, note, createdAt
- `settings` (id = `main`): prices[{from, price}], defaultPayment, weekdays[]
- `settings` (id = `cash`): entries[{id, date, amount, note, createdAt}] – ruční stavy pokladny, nejnovější podle data je „Pokladna celkem“
- `members`: email, role

Zůstatek = součet plateb − součet cen tréninků (cena podle ceníku platného k datu tréninku).

## Známá omezení
- Přihlášení v prohlížeči trvá, dokud se uživatel neodhlásí (ztracený telefon → odebrat z `members`).
- Bezplatný projekt se po týdnu bez používání uspí; probudí se v administraci Supabase.
- Při souběžné úpravě téhož záznamu vyhrává poslední uložení.
