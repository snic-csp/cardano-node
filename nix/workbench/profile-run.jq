def profile_timing($prof;
                   $future_offset;
                   $start;
                   $start_human;
                   $start_tag;
                   $startTime):
  ($startTime + "Z" | fromdateiso8601 | . + $prof.derived.shutdown_time)      as $shutdown_end
| ($startTime + "Z" | fromdateiso8601 | . + $prof.derived.generator_duration) as $workload_end
| ( [$shutdown_end, $workload_end]
  | map(select(. != null))
  | min)                                                                as $earliest_end
|
{ future_offset:   $future_offset
, start:           $start
, shutdown_end:    $shutdown_end
, workload_end:    $workload_end
, earliest_end:    $earliest_end

, start_tag:       $start_tag
, start_human:     $start_human
, startTime:       $startTime
, shutdownTime:    ($shutdown_end | todateiso8601)
, workloadEndTime: ($workload_end | todateiso8601)
, earliestEndTime: ($earliest_end | todateiso8601)
};

def timing_pretty_describe($t):
  [ "workbench | timing for:  \($t.start_tag)"
  , "  - future offset:      \($t.future_offset)"
  , "  - start time:         \($t.startTime)"
  , "  - shutdown time:      \($t.shutdownTime)"
  , "  - workload time:      \($t.workloadEndTime)"
  , "  - earliest end:       \($t.earliestEndTime)"
  , ""
  ] | join("\n");

def profile_node_specs($env; $prof):
  $prof.composition.n_bft_hosts      as $n_bfts
| $prof.composition.n_pool_hosts     as $n_pools
| $prof.composition.n_singular_hosts as $n_singular_pools
| ([range(0;
          $n_bfts)]
   | map({ i: .
         , kind: "bft"
         , pools: 0
         }))
   as $bfts
| ([range($n_bfts;
          $n_bfts + $n_pools)]
   | map({ i: .
         , kind: "pool"
         , pools: (if . - $n_bfts < $n_singular_pools
                   then 1
                   else $prof.composition.dense_pool_density end)
         }))
   as $pools
| ([range($n_bfts + $n_pools;
          $n_bfts + $n_pools +
          if $prof.composition.with_proxy then 1 else 0 end)]
   | map({ i: .
         , kind: "proxy"
         , pools: 0
         }))
   as $proxies
| ([range($n_bfts + $n_pools
          + if $prof.composition.with_proxy then 1 else 0 end;
          $n_bfts + $n_pools
          + if $prof.composition.with_proxy then 1 else 0 end
          + if $prof.composition.with_observer then 1 else 0 end)]
   | map({ i: .
         , kind: "observer"
         , pools: 0
         }))
   as $observers
| ($bfts + $pools + $proxies + $observers
   | map(. +
         { name:       "node-\(.["i"])"
         , isProducer: ([.kind == "bft", .kind == "pool"] | any)
         , port:
           (if $env.staggerPorts
            then $env.basePort + .i
            else $env.basePort
            end)
         }))
| map({ key: .name, value: .})
| from_entries;
