# QuickBooks data model

This diagram summarizes the QuickBooks entities used by the bridge and how operational transactions feed the
general ledger and financial reports.

All entities in this diagram are native QuickBooks sandbox records. The application keeps no local relational
mirror, mapping table, duplicate index, replay record, or audit row.

For the transformations applied when these entities cross the Ruby boundary, see
[`quickbooks_data_normalization.md`](quickbooks_data_normalization.md).

```mermaid
flowchart TB
    Company["QuickBooks company / realm"] --> Lists["Reference lists"]
    Lists --> Accounts["Accounts"]
    Lists --> Customers["Customers"]
    Lists --> Vendors["Vendors"]
    Lists --> Employees["Employees"]
    Lists --> Items["Products and services"]
    Lists --> Tax["Tax codes and rates"]

    Customers --> Invoices["Invoices"]
    Invoices --> Payments["Customer payments"]

    Vendors --> Bills["Bills"]
    Bills --> BillPayments["Bill payments"]

    Employees --> Time["Time activities"]
    Accounts --> JournalEntries["Journal entries"]
    Items --> Invoices

    Invoices --> Ledger["General ledger"]
    Payments --> Ledger
    Bills --> Ledger
    BillPayments --> Ledger
    JournalEntries --> Ledger

    Ledger --> Reports["Financial reports"]
```
