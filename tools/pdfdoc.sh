pod2pdf ../bin/dra-delete 
pod2pdf ../bin/dra-backup 
pod2pdf ../bin/dra-convert
pod2pdf ../bin/dra-mdss
pod2pdf ../bin/dra-notify
pod2pdf ../bin/dra-run
pod2pdf ../bin/dra-transfer
pod2pdf ../bin/dra-video
pod2pdf ../bin/dra-video-run
pdftk ../bin/*.pdf cat output out
rm ../bin/*.pdf
mv out ../manual.pdf

