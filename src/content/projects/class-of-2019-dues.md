---
title: Class of 2019 Dues Management System
client: Class of 2019, Tanoso Anglican J.H.S "A"
category: Group finance · Web application
year: 2026
status: Planned
summary: A transparent way for a former school group to collect and account for monthly dues, with mobile money, two-admin approval, receipts and audit logs.
services: [System specification, Supabase Auth, PostgreSQL & RLS, Mobile-first UI]
featured: true
order: 3
---

## The need
Collecting GH₵20 a month from every member of a former school group only works if everyone can trust the records. The group needed accountability built in, not a spreadsheet only one person controls.

## The design
- Member accounts and administrator accounts.
- Payments by mobile money, recording which month or months each payment covers.
- Members submit their transaction reference and payment time.
- **Every payment needs approval from two administrators.**
- Digital receipts and Excel reports.
- Payment reminders.
- Group expenses and running balance.
- Audit logs for full accountability.

## The approach
Before writing any code, I produced a complete specification: system requirements, database schema, Row Level Security policies and implementation instructions, for a mobile-first app built with HTML, CSS and JavaScript on Supabase Authentication and PostgreSQL.
