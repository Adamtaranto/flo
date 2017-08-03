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

# GNU parallel
cd ext
curl http://ftp.gnu.org/gnu/parallel/parallel-20150722.tar.bz2
tar xvf parallel-20150722.tar.bz2
rm parallel-20150722.tar.bz2
cd parallel-20150722
./configure
make
cd ../..

# Genometools
cd ext
curl -O https://github.com/genometools/genometools/archive/v1.5.6.tar.gz
tar xvf v1.5.6.tar.gz
rm v1.5.6.tar.gz
cd genometools-1.5.6
make cairo=no errorcheck=no
