# Copyright 2017 Anurag Priyam - MIT License
#
# Annotation lift over pipeline.
#
# Based on the lift over procedure deseribed at:
# http://genomewiki.ucsc.edu/index.php/LiftOver_Howto &
# http://hgwdev.cse.ucsc.edu/~kent/src/unzipped/hg/doc/liftOver.txt
#
# Additional references:
# http://genomewiki.ucsc.edu/index.php/Chains_Nets
# https://genome.ucsc.edu/goldenPath/help/net.html
# http://genome.ucsc.edu/goldenpath/help/chain.html
# http://asia.ensembl.org/info/website/upload/psl.html
#
# The pipeline depends on GNU parallel, genometools (> 1.5.5) and the following
# tools from UCSC-Kent tookit: faSplit, faToTwoBit, twoBitInfo, blat, axtChain,
# chainSort, chainMergeSort, chainSplit, chainNet, netChainSubset, and liftOver.

require 'yaml'
require 'tempfile'

# Reads config file. Runs task to create chain file, then runs liftOver.
task 'default' do
  # Check for presence of config file. Exit if not found.
  unless File.exist? ENV['FLO_OPTS']
    puts "Config file not found. See README for how to use flo."
    exit!
  end

  # Read config file.
  CONFIG = YAML.load_file ENV['FLO_OPTS']

  # Add dirs specified in config to PATH.
  Array(CONFIG[:add_to_path]).each { |path| add_to_PATH path }
  
  # Set project directory location
  projectDir = CONFIG[:projectDir]

  # Set unique directory name for rhis run 
  runStamp = Time.now.strftime("%Y%m%d%H%M%S%3N")
  RUNDIR = "#{projectDir}/run_#{runStamp}"
  mkdir RUNDIR

  # Create chain file.
  liftchain "#{RUNDIR}/liftover.chn"

  # Lift over the given GFF3 files.
  Array(CONFIG[:lift]).each do |inp|
    gffbase = File.basename(inp, '.*')
    outdir = "#{RUNDIR}/#{gffbase}"
    mkdir outdir

    # Lift over the annotations from source assembly to target assembly.
    sh "liftOver -gff #{inp} #{RUNDIR}/liftover.chn #{outdir}/lifted.gff3" \
       " #{outdir}/unlifted.gff3"

    # Clean lifted annotations.
    sh "#{__dir__}/gff_recover.rb #{outdir}/lifted.gff3 2> unprocessed.gff |" \
      " gt gff3 -tidy -sort -addids -retainids - > #{outdir}/lifted_cleaned.gff"

    # Symlink input gff to outdir.
    sh "ln -s #{File.expand_path inp} #{outdir}/input.gff"

    # Compare input and lifted gff at CDS level.
    sh "#{__dir__}/gff_compare.rb cds #{RUNDIR}/source.fa #{RUNDIR}/target.fa" \
       " #{outdir}/input.gff #{outdir}/lifted_cleaned.gff"         \
       " > #{outdir}/unmapped.txt"
  end
end

# Task to create chain file.
def liftchain(outfile)
  #Future: Add option to recycle old chainfile #
  processes = CONFIG[:processes]
  blat_opts = CONFIG[:blat_opts]
  
  cp CONFIG[:source_fa], "#{RUNDIR}/source.fa"
  cp CONFIG[:target_fa], "#{RUNDIR}/target.fa"

  to_2bit "#{RUNDIR}/source.fa"
  to_2bit "#{RUNDIR}/target.fa"

  to_sizes "#{RUNDIR}/source.2bit"
  to_sizes "#{RUNDIR}/target.2bit"

  # Partition target assembly.
  sh "faSplit sequence #{RUNDIR}/target.fa #{processes} #{RUNDIR}/chunk_"

  parallel Dir["#{RUNDIR}/chunk_*.fa"],
    'faSplit -oneFile size %{this} 5000 %{this}.5k -lift=%{this}.lft &&'       \
    'mv %{this}.5k.fa %{this}'

  # BLAT each chunk of the target assembly to the source assembly.
  parallel Dir["#{RUNDIR}/chunk_*.fa"],
    "blat -noHead #{blat_opts} #{RUNDIR}/source.fa %{this} %{this}.psl"

  parallel Dir["#{RUNDIR}/chunk_*.fa"],
    "liftUp -type=.psl -pslQ -nohead"                                          \
    " %{this}.psl.lifted %{this}.lft warn %{this}.psl"

  # Derive a chain file each from BLAT's .psl output files.
  parallel Dir["#{RUNDIR}/chunk_*.psl.lifted"],
    'axtChain -psl -linearGap=medium'                                          \
    " %{this} #{RUNDIR}/source.2bit #{RUNDIR}/target.2bit %{this}.chn"

  # Sort the chain files.
  parallel Dir["#{RUNDIR}/chunk_*.chn"],
    'chainSort %{this} %{this}.sorted'

  # Combine sorted chain files into a single sorted chain file.
  sh "chainMergeSort #{RUNDIR}/*.chn.sorted | chainSplit #{RUNDIR} stdin -lump=1"
  mv "#{RUNDIR}/000.chain", "#{RUNDIR}/combined.chn.sorted"

  # Derive net file from combined, sorted chain file.
  sh 'chainNet'                                                                \
     " #{RUNDIR}/combined.chn.sorted #{RUNDIR}/source.sizes #{RUNDIR}/target.sizes"             \
     " #{RUNDIR}/combined.chn.sorted.net /dev/null"

  # Subset combined, sorted chain file.
  sh 'netChainSubset'                                                          \
     " #{RUNDIR}/combined.chn.sorted.net #{RUNDIR}/combined.chn.sorted"                   \
     " #{RUNDIR}/liftover.chn"
end

### Helpers ###

def add_to_PATH(path)
  return unless path
  return unless File.directory? path
  return if ENV['PATH'].split(':').include? path
  ENV['PATH'] = "#{path}:#{ENV['PATH']}"
end

def to_2bit(fas)
  sh "faToTwoBit #{fas} #{fas.ext('2bit')}"
end

def to_sizes(twobit)
  sh "twoBitInfo #{twobit} stdout | sort -k2nr > #{twobit.ext('sizes')}"
end

def parallel(files, template)
  name = template.split.first
  jobs = files.map { |file| template % { :this => file } }
  joblst = "#{RUNDIR}/joblst.#{name}"
  joblog = "#{RUNDIR}/joblog.#{name}"
  File.write(joblst, jobs.join("\n"))
  sh "parallel --joblog #{joblog} -j #{jobs.length} -a #{joblst}"
end