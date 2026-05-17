-- Migration to add icon_url to categories table
ALTER TABLE categories ADD COLUMN icon_url VARCHAR(255) NULL;
