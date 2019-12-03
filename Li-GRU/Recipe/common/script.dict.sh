grep -Pv "^[A-Z]|\-|\(|\)|’|\=|é|ï" dictionary | sed -r -e "s/.*/\U&/" | sort -u | sort -n > lexicon
# grep -P "[^A-Z0-9' ]" lexicon # should only have "#"-related entries

grep -Po "^[A-Z0-9#']+ " lexicon | sed -r "s/ +$//" | sort -u | sort -n > vocab
