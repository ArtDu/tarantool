## bugfix/box

* All the DDL functions from `box.schema` module are wrapped into transaction
  to avoid database inconsistency on failed operation (gh-4348).
