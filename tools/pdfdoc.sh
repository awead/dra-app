pod2pdf --nofooter --title dra-delete ../bin/dra-delete > dra-delete.pdf
pod2pdf --nofooter --title dra-backup ../bin/dra-backup > dra-backup.pdf
pod2pdf --nofooter --title dra-convert ../bin/dra-convert > dra-convert.pdf
pod2pdf --nofooter --title dra-mdss ../bin/dra-mdss > dra-mdss.pdf
pod2pdf --nofooter --title dra-notify ../bin/dra-notify > dra-notify.pdf
pod2pdf --nofooter --title dra-run ../bin/dra-run > dra-run.pdf
pod2pdf --nofooter --title dra-transfer ../bin/dra-transfer > dra-transfer.pdf
pdftk *.pdf cat output out
rm *.pdf
mv out ../manual.pdf

