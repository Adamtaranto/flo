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
  runDir = "#{projectDir}/run_#{runStamp}"

  # Create chain file.
  task('#{runDir}/liftover.chn').invoke

  # Lift over the given GFF3 files.
  Array(CONFIG[:lift]).each do |inp|
    gffbase = File.basename(inp, '.*')
    outdir = "#{runDir}/#{gffbase}"
    mkdir outdir

    # Lift over the annotations from source assembly to target assembly.
    sh "liftOver -gff #{inp} #{runDir}/liftover.chn #{outdir}/lifted.gff3" \
       " #{outdir}/unlifted.gff3"

    # Clean lifted annotations.
    sh "#{__dir__}/gff_recover.rb #{outdir}/lifted.gff3 2> unprocessed.gff |" \
      " gt gff3 -tidy -sort -addids -retainids - > #{outdir}/lifted_cleaned.gff"

    # Symlink input gff to outdir.
    sh "ln -s #{File.expand_path inp} #{outdir}/input.gff"

    # Compare input and lifted gff at CDS level.
    sh "#{__dir__}/gff_compare.rb cds #{runDir}/source.fa #{runDir}/target.fa" \
       " #{outdir}/input.gff #{outdir}/lifted_cleaned.gff"         \
       " > #{outdir}/unmapped.txt"
  end
end

# Task to create chain file.
file '#{runDir}/liftover.chn' do
  mkdir '#{runDir}'

  processes = CONFIG[:processes]
  blat_opts = CONFIG[:blat_opts]

  cp CONFIG[:source_fa], '#{runDir}/source.fa'
  cp CONFIG[:target_fa], '#{runDir}/target.fa'

  to_2bit '#{runDir}/source.fa'
  to_2bit '#{runDir}/target.fa'

  to_sizes '#{runDir}/source.2bit'
  to_sizes '#{runDir}/target.2bit'

  # Partition target assembly.
  sh "faSplit sequence #{runDir}/target.fa #{processes} #{runDir}/chunk_"

  parallel Dir['#{runDir}/chunk_*.fa'],
    'faSplit -oneFile size %{this} 5000 %{this}.5k -lift=%{this}.lft &&'       \
    'mv %{this}.5k.fa %{this}'

  # BLAT each chunk of the target assembly to the source assembly.
  parallel Dir['#{runDir}/chunk_*.fa'],
    "blat -noHead #{blat_opts} #{runDir}/source.fa %{this} %{this}.psl"

  parallel Dir['#{runDir}/chunk_*.fa'],
    "liftUp -type=.psl -pslQ -nohead"                                          \
    " %{this}.psl.lifted %{this}.lft warn %{this}.psl"

  # Derive a chain file each from BLAT's .psl output files.
  parallel Dir['#{runDir}/chunk_*.psl.lifted'],
    'axtChain -psl -linearGap=medium'                                          \
    ' %{this} #{runDir}/source.2bit #{runDir}/target.2bit %{this}.chn'

  # Sort the chain files.
  parallel Dir["#{runDir}/chunk_*.chn"],
    'chainSort %{this} %{this}.sorted'

  # Combine sorted chain files into a single sorted chain file.
  sh 'chainMergeSort #{runDir}/*.chn.sorted | chainSplit run stdin -lump=1'
  mv '#{runDir}/000.chain', '#{runDir}/combined.chn.sorted'

  # Derive net file from combined, sorted chain file.
  sh 'chainNet'                                                                \
     ' #{runDir}/combined.chn.sorted #{runDir}/source.sizes #{runDir}/target.sizes'              \
     ' #{runDir}/combined.chn.sorted.net /dev/null'

  # Subset combined, sorted chain file.
  sh 'netChainSubset'                                                          \
     ' #{runDir}/combined.chn.sorted.net #{runDir}/combined.chn.sorted'                    \
     ' #{runDir}/liftover.chn'
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
  joblst = "#{runDir}/joblst.#{name}"
  joblog = "#{runDir}/joblog.#{name}"
  File.write(joblst, jobs.join("\n"))
  sh "parallel --joblog #{joblog} -j #{jobs.length} -a #{joblst}"
end
