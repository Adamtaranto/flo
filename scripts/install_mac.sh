# UCSC-Kent
mkdir -p ext/kent/bin
cd ext/kent/bin
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/liftUp"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/faSplit"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/liftOver"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/axtChain"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/chainNet"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/blat/blat"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/chainSort"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/faToTwoBit"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/twoBitInfo"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/chainSplit"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/chainMergeSort"
curl -O "http://hgdownload.cse.ucsc.edu/admin/exe/macOSX.x86_64/netChainSubset"
chmod +x *
cd -

