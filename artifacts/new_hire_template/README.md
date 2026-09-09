# New hire AcroForm template

- `new_hire_acroform.pdf`: blank, four-page PDF with selectable text and 30 fillable text fields.
- `new_hire_filled_example.pdf`: editable sample populated with the provided synthetic data.
- `field_map.json`: exact fully qualified AcroForm names, labels, page numbers and flags.
- `user_data.example.json`: normalized example JSON. HTML space entities and the escaped email @ from the pasted message were normalized.
- `build_template.py`: reproducible generator and local validation (ReportLab, pypdf, pypdfium2, Pillow).

The source was rebuilt into four pages, retaining the onboarding steps and form information in a revised layout. Browser headers, refresh instructions, web submission buttons, file-upload control and emailed-response checkbox were omitted. Supporting documents are handled separately. Record references from the payload were added.

Names are relative to the supplied payload, such as `employee.firstName`, without a `user_data.` prefix. PDF fields use parent/child dictionaries so these are fully qualified names. All fields are text, including former dropdowns and boolean fields. Serialize booleans as lowercase `true` / `false`; dates as YYYY-MM-DD. Notification type uses the payload value (for example, `newHireRehire`). Notes, prior certification details and rate reason allow multiple lines. The blank template has no example/default values. Required flags indicate required data; they do not enforce authorization or require an attestation value of true. Attestation is not a digital signature.

## Box Doc Gen

This is a locally validated AcroForm, not a Box-validated integration. No files were uploaded to Box and no Doc Gen job was run. Confirm that the PDF template processing in your Box environment recognizes these AcroForm field names and resolves the nested JSON paths before production use. No visible `{{...}}` tags are included.

Box documents PDF template upload in its Salesforce setup guide:
https://support.box.com/hc/en-us/articles/48670280271635-Setting-up-Box-Doc-Gen-in-Salesforce

The Doc Gen API guide calls the generation payload `document_generation_data[].user_input`. If your application calls it `user_data`, map that object into `user_input` when constructing the API request:
https://developer.box.com/guides/docgen/generate-document

## Validation performed

Checked exact coverage of all 30 JSON leaf paths, text field types, blank template values, populated sample values after save/reopen, multiline Notes flag, selectable page text and absence of raster page images. Rendered and visually reviewed all four sample pages. PDF fields have fixed dimensions: longer production values may scroll in a viewer and should be checked for print clipping.
