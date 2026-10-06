# Data availability

The original Amazon FBA workbook is proprietary and is **not distributed** with this repository.

The analytical pipeline only reads the `IL_AWD` sheet and requires these fields:

- `Disposition`
- `LedgerDayUTC`
- `Master SKU`
- `Final_OnHand_Effective`

Account/mapping sheets such as `Map_Loc` and `Map_SKU` are not required and are deliberately not read by the reconstructed pipeline.

Authorized users can point the pipeline to a local workbook by setting the `THESIS_DATA_PATH` environment variable. Do not commit the source workbook to this repository.
