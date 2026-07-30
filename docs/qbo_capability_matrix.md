# QuickBooks capability matrix

OpenAPI contract 2.0.0 exposes the current finance surface below. Every capability calls the QuickBooks Online
sandbox through Rails; none call Intuit from the browser, persist a local finance record, or perform a
create-time duplicate-name preflight.

| Capability | GET | POST | Rails behavior |
| --- | ---: | ---: | --- |
| Eligible Accounts | 1 | 0 | Active eligible accounts; excludes A/R and A/P for the simple Journal Entry flow |
| Financial reports | 5 | 0 | Profit & Loss, Balance Sheet, Cash Flow, General Ledger, Trial Balance |
| Journal Entries | 1 | 1 | Balanced two-line create, current account validation, readback |
| Employees | 1 | 1 | Accounting API Employee; not full payroll |
| Time Activities | 1 | 1 | Employee/vendor reference validation and readback |
| Tax Codes | 1 | 1 | Controlled TaxCode create without local duplicate-name preflight |
| Inventory Items | 1 | 1 | Decimal-safe quantity/cost and supporting-account validation |
| Customers | 1 | 1 | Controlled Customer create without local duplicate-name preflight |
| Vendors | 1 | 1 | Controlled Vendor create without local duplicate-name preflight |
| Invoices | 1 | 1 | One-line Invoice create with current customer/item references |
| Bills | 1 | 1 | One-line Bill create with current vendor/account references |
| Customer Payments | 1 | 1 | Applies to a current open Invoice; validates open balance |
| Bill Payments | 1 | 1 | Check-style payment of a current open Bill; validates open balance |
| **Finance total** | **17** | **11** | **28 operations** |

`GET /health` and OAuth/dashboard routes are outside the finance count.

Every POST receives a fresh internal QBO `requestid`, makes one outbound write attempt, reads the returned entity
back, verifies it, and returns HTTP 201. There is no public idempotency key, replay response, local audit history,
or automatic POST retry. Repeated POSTs may create duplicate sandbox records.

The connection and tokens are process-local. The capability surface is sandbox-only, single-process, ephemeral,
and unsuitable for production.
