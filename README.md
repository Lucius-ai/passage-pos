# Passage POS

Bilingual (EN/Myanmar) Point-of-Sale system built for small businesses in Thailand and Myanmar.

## Stack
- **Frontend**: Vanilla HTML/CSS/JS (single file)
- **Database**: Supabase (Postgres + Realtime)
- **Hosting**: Netlify (via GitHub)

## Setup

### 1. Supabase
1. Go to your Supabase project → SQL Editor
2. Run the contents of `schema.sql`
3. Your tables and RLS policies are now ready

### 2. Deploy to Netlify
1. Push this repo to GitHub
2. Go to [netlify.com](https://netlify.com) → "Import from Git"
3. Select your GitHub repo
4. Build settings: leave blank (static site)
5. Click "Deploy site"

### 3. First run
- Open your Netlify URL
- Complete the Setup Wizard
- Your data is now stored in Supabase and syncs across devices in real-time

## Features
- Multi-user (Admin / Cashier roles)
- Sales POS with cart, discounts, multiple payment methods
- Cash change calculator
- Inventory management with barcode support
- Customer accounts with wallet/credit
- Sales history with void and notes
- Hold orders (park a cart, come back later)
- Finance dashboard with CSV export
- Real-time sync between devices (Supabase Realtime)
- Offline fallback via localStorage cache
- Bilingual EN / Myanmar
- Light / Dark theme

## Development
Open `index.html` directly in your browser — no build step needed.
