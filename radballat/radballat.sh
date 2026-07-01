curl "https://www.vfh-muecheln.de/Radball.at/Vorschau2.htm" | grep "<a target=\"_self\" href=" | sed 's/\t//g' | sed 's/target="_self"//g' | sed 's/<a  href="//g' | sed 's/".*//g' | sed 's/ //g'| grep ".htm" | grep "https://" > radballat.links

base="./radball.at"
while IFS= read -r link; do
	mkdir -p $(dirname "$base/$link")
	curl "$link" > "$base/$link"
done < radballat.links

rm radballat.links
