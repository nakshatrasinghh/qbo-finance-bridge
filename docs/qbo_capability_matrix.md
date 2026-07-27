# QuickBooks capability matrix

The current app exposes a controlled local QuickBooks Online sandbox surface.

| Data | QuickBooks representation | GET | POST | Accounting impact | Status |
|---|---|---|---|---|---|
| Company connection | CompanyInfo/OAuth | Yes | OAuth only | None | Implemented |
| Finance reports | ProfitAndLoss, BalanceSheet, CashFlow, GeneralLedger, TrialBalance | Five explicit Rails GETs | No report POST | None; QuickBooks calculates from transactions | Implemented |
| Journal Entry account choices | Account | Eligible active Account query | No Account creation | None from reading | Implemented |
| Financial records | JournalEntry | Date-filtered and paginated GET | Audited/idempotent balanced create + readback | Selected Accounts are debited/credited | Implemented |
| Submission audit history | **Local-only** `quickbooks_sync_operations` | PostgreSQL GET | Rows produced by create APIs | None from reading | Implemented |
| Employee directory | Employee | Active Employee query | Names plus optional email/phone; no payroll/PII fields | Non-posting master data | Implemented |
| Employee time | TimeActivity | Recent employee time query | Active Employee, ISO date, whole hours/minutes, description | Records time; does not calculate payroll or invoice | Implemented |
| Tax configuration | TaxCode, TaxRate, TaxAgency, TaxService | Codes, distinct rates, and agencies | New TaxCode from one existing active rate | Configuration only; no filing/payment/calculation | Implemented |
| Inventory master data | Item plus supporting Accounts | Inventory Items and eligible account choices | New Inventory Item with decimal-safe quantity/cost/price and readback | Positive opening quantity/cost can affect inventory value | Implemented |
| Customers | Customer | Active Customer query | Unique display name and optional company/contact data | Non-posting list record | Implemented |
| Vendors | Vendor | Active Vendor query | Unique display name and optional company/contact data | Non-posting list record | Implemented |
| Sales invoices | Invoice plus Customer and Item choices | Up to 1,000 Invoices and active references | One sale Item line, ISO dates, decimal amount, readback | Increases sales/receivable and may affect inventory | Implemented |
| Vendor bills | Bill plus Vendor and Account choices | Up to 1,000 Bills and active references | One account-based expense line, ISO dates, decimal amount, readback | Increases expense/payable | Implemented |
| Customer receipts | Payment plus open Invoice choices | Payments and open Invoices | One Payment linked to one open Invoice, capped at current balance | Reduces receivable; QuickBooks chooses its default deposit behavior | Implemented |
| Vendor disbursements | BillPayment plus open Bill/bank choices | BillPayments, open Bills, active bank Accounts | One check-style BillPayment linked to one Bill, capped at current balance | Reduces cash and payable | Implemented |
| Browser views/CSV | Rails HTML/JavaScript | API-backed tables and existing financial CSV projections | No extra API write | None from display/export | Implemented |

Not supported: payroll runs, compensation, paychecks, deductions, benefits, payroll calculations or filings;
tax-rate/agency creation, tax calculation, returns, payments, or filings; inventory adjustments, purchase orders,
sales receipts, categories, bundles, or Account auto-creation; invoice delivery, electronic payment processing,
multi-line editing, refunds, credits, arbitrary JSON uploads, production QuickBooks, bulk synchronization, or
reports beyond the five listed reports.
