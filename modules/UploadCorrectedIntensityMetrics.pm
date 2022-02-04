# CorrectedIntMetricsOut.bin 
#
# Byte 0: File version
# Byte 1: Length of each record
#
# Followed by a repeated 64-byte structure:
#
# 2 bytes: lane                     [uint16]
# 2 bytes: tile                     [uint16]
# 2 bytes: cycle                    [uint16]
# 2 bytes: average intensity        [uint16]
#
# 4*4 bytes: Average corrected intensity by channel:
#            A, C, G, T             4*[uint16]
#
# 4*4 bytes: Avg corr. int. for called clusters:
#            A, C, G, T             4*[uint16]
#
# 4*5 bytes: number of base calls for...
#        No call, A, C, T, G        5*[float]
#
# 4 bytes: signal to noise ratio    [float]

use strict;

sub uploadCorrectedIntensityMetrics($$$) {
    my ($RunID, $binFile, $db) = @_;
    open(INPUT, $binFile) || die "Couldn't open $binFile";

    local $/;                        # Slurp mode:     Prevent incorrect newline interpretation of binary data
    my $line = <INPUT>;

    my @f = unpack("cc(SSSSSSSSSSSSLLLLLf)*", $line);   # c: signed char             [1 byte]
    my ($fileVersion, $numRecords) = ($f[0], $f[1]);    # S: unsigned short (uint16) [2 bytes]
                                                        # f: single precision float  [4 bytes]
    my $c = 2;                                          # L: unsigned long           [4 bytes]

    my $count = 1;
    while (defined($f[$c])) {
        my     ($lane, $tile, $cycle, $avgIntensity,
                $correctedInt_A, $correctedInt_C, $correctedInt_G, $correctedInt_T,
                $correctedInt_A_cluster, $correctedInt_C_cluster, $correctedInt_G_cluster, $correctedInt_T_cluster,
                $calls_none, $calls_A, $calls_C, $calls_T, $calls_G, $SNR) =

               ($f[$c+0], $f[$c+1], $f[$c+2], $f[$c+3],
                $f[$c+4], $f[$c+5], $f[$c+6], $f[$c+7],
                $f[$c+8], $f[$c+9], $f[$c+10], $f[$c+11],
                $f[$c+12], $f[$c+13], $f[$c+14], $f[$c+15], $f[$c+16], $f[$c+17]);

        if (lc $SNR eq 'nan' or lc $SNR eq '-nan') {
            $SNR = -1;
        }

        my $query = q{
            INSERT
            INTO    MiSeqQC_CorrectedIntensities
                    (
                    RunID,
                    lane,
                    tile,
                    cycle,
                    averageIntensity,
                    correctedIntensity_A,
                    correctedIntensity_C,
                    correctedIntensity_G,
                    correctedIntensity_T,
                    numCalls_noCall,
                    numCalls_A,
                    numCalls_C,
                    numCalls_G,
                    numCalls_T,
                    Signal_to_noise
                    )
            VALUES  (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        };
        my $sth = $db->prepare($query);
        $sth->execute(
            $RunID,
            $lane,
            $tile,
            $cycle,
            $avgIntensity,
            $correctedInt_A,
            $correctedInt_C,
            $correctedInt_G,
            $correctedInt_T,
            $calls_none,
            $calls_A,
            $calls_C,
            $calls_T,
            $calls_G,
            $SNR);

        $c+= 18;
        if ($count % 2500 == 0) { my @t = localtime(time); my $time = "$t[2]:$t[1]:$t[0]";  print "[$time] $RunID - CorrectedIntensities, record $count\n"; }
        $count++;
        }
    close(INPUT);
    undef $line;
    $db->commit();
    print "Committed transaction for MiSeqQC_CorrectedIntensities!\n\n";
}

1;
