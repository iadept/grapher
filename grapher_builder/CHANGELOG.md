## 0.7.2

Support analyzer 14.x and build 5.x (Flutter 3.50 / Dart 3.14)
Fix `GrapherField.defaultValue` for non-nullable fields: missing key now falls back to the default instead of throwing a cast error

## 0.7.1

Fix validation

## 0.7.0

Add union support for list fields (items of unknown types are skipped)
Add fragments: `GrapherObject.fragment`, `GrapherField.fragment`
Add recursive fields with `GrapherField.maxDepth`

## 0.6.0

Add subscription input support

## 0.5.2

Update dep constraint

## 0.5.1

Update dep constraint
Add support deprecated for enum

## 0.5.0

Add createFromMap for input
Exit from builder on validation error (throwCriticalError config flag)

## 0.4.0

Improve validation

## 0.3.0

Add default value for field

## 0.2.4

Improve validation

## 0.2.3

Improve validation

## 0.2.2

Add createToMap param to object

## 0.2.1

Update docs 

## 0.2.0

Add isFinal Enum param 

## 0.1.3

Add typename to query body

## 0.1.2

Update docs
Change actions result signature

## 0.1.1

Update docs

## 0.1.0

Initial release
