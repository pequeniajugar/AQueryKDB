/
  Base library for aquery code, version 1.0
  Please report any bugs to jpc485@nyu.edu
\

// Translation utilities
// initialize state
.aq.initQueryState:{.aq.cd:s!s:`$(); .aq.pc:s;};

// Generate column dictionary
.aq.gencd:{[t;sn;rename]
  prefix:$[rename;sn,"__";""];
  $[0=count sn;
    c!c:cols t;
    ((`$(sn,"."),/:sc),c)!(2*count c)#`$prefix,/:sc:string c:cols t
    ]
   };

// rename columns using a dictionary
.aq.drcols:{[t;d](c^d c:cols t) xcol t};
// rename columns using a prefix
.aq.rcols:{[t;p] $[0=count p; t; .aq.drcols[t;c!`$(p,"__"),/:string c:cols t]]};

// initialize table and add to relevant global info
.aq.initTable:{[t;nm;rename]
   // given tables column dictionary
   tc:.aq.gencd[t;nm;rename];
   //drop ambiguous cols from map
   .aq.cd:{(key[y] inter .aq.pc) _ x,y}[.aq.cd;tc];
   // add original columns to .aq.pc
   .aq.pc:.aq.pc union cols t;
   // return table w/ renamed columns
   $[rename;.aq.rcols[t;nm];t]
 };

.aq.initState:{.aq.gencd:{x!x}`$(); .aq.pc:`$();};

// sort column names by attribute
.aq.scbix:{[m] iasc `s`p`g`u?exec c!a from m};
.aq.swix0:{[c;w]
  w iasc min each c?fw@'where each type[`]=(type each) each fw:(raze/) each w
 };
// reorder where clauses based on indices
.aq.reorderFilter:{[v;w]
 // no point in reording if we don't have attributes
 // otherwise reorder locally between aggregates according to safe principle
 $[exec all null a from m:meta v; w; .aq.swix0[.aq.scbix m;w]]
 };

// sort a table by direction-column tuples d and sort only columns c
.aq.sort:{[t;d;c]
 if[0h<>type first d;'"must be list of tuples of direction and column"];
 ix:{[t;ix;dc] ix dc[0] (t dc[1]) ix}[t;;]/[::;reverse d];
 cl:(),c;
 @[t;cl inter $[99h=type t;key t;cl];@[;ix]]
 }

// sort a table when it is grouped (handles group columns appropriately)
.aq.sortGrouped:{[tg;d;c]
  k:keys tg;
  // remove tuples involving grouping direction. semantics indicate grouping is after sort
  // so new order can be imposed via grouping e.g. select * by c1, c3 from `c1 xasc `c3 xdesc t
  dc:d where not (last each d) in k;
  $[(0=count tg)|0=count dc;tg;.aq.sort[ ;dc;c] each tg]
 }


// join using preparation
.aq.joinUsingPrep:{[cs;j]
  $[2<>count m:cs where cs like "*__",s:string j;
    '"ambig-join:",s;
    `rename`remap!(m!2#n;((.aq.cd?m),j)!(1+count m)#n:`$"_"sv string m)
    ]
  };

.aq.joinUsing:{[jf;l;r;cs]
  // join using information
  jui:raze each flip .aq.joinUsingPrep[cols[l],cols r;] each (),cs;
  // remap column references
  .aq.cd,:jui`remap;
  l:.aq.drcols[l;jui`rename];
  r:.aq.drcols[r;jui`rename];
  jf[.aq.cd cs;l;r]
 }

//full outer join using (definition compliant with traditional sql semantics
// from ej
k).aq.ejix:{(=x#z:0!z)x#y:0!y};
.aq.foju:{
  nix:.aq.ejix[x:(),x;y:0!y;z:0!z];
  iz:raze nix; //indices in z for equijoin
  iy:where count each nix; // indices in y for equijoin
  ejr:y[iy],'(x _ z) iz; // perform equi join
  my:select from y where not i in iy; // records in y not in equi join
  mz:select from z where not i in iz; // records z not in equi join
  ejr upsert/(my;mz) // add missing records
  };
// nested join
.aq.nj:{[t1;t2;p] raze {?[x,'count[x]#enlist y;z;0b;()]}[t1; ;p] each t2};

// hash join
.aq.hj:{[t1;t2;a1;a2;p]
  // argument preparation
  a1,:();a2,:();p:$[0<>type first p;enlist p;p];hasneq:any not (=)~/:first each p;
  targs:$[count[t2]>count t1;(t1;t2;a1;a2);(t2;t1;a2;a1)];
  s:targs 0;b:targs 1;sa:targs 2;ba:targs 3;
  // here the "hash function" is identity of join attributes, extract index
  bti:?[s;();sa!sa;`i];
  // hash larger and drop no matches
  bw:?[b;();ba!ba;`i];
  matches:((sa xcol key bw) inter key bti)#bti;
  // perform nj for all matches using complete join predicate
  // if has any predicate that is not equality based otherwise just cross (guaranteed matches)
  inner:b bw ba xcol key matches;
  outer:s value matches;
  $[hasneq;raze .aq.nj'[inner;outer;(count matches)#enlist p];raze {x cross y}'[inner;outer]]
 };

// check if tables are keyed on join keys
// if so use ij instead of ej, much more performant, same semantics in such a case
.aq.iskey:{(count[k]>0)&min (k:keys x) in y};

// faster equi join based on keyed or not
.aq.ej:{[k;t1;t2] $[(kt2:.aq.iskey[t1;k])|kt1:.aq.iskey[t2;k]; $[kt1;t1 ij t2;t2 ij t1]; ej[k;t1;t2]]};

// check attributes
.aq.chkattr:{[x;t] any (.aq.cd where any each flip .aq.cd like/: "*",/:string (),x) in exec c from meta t where not null a};

// enlist for variables inside functions
.aq.funEnlist:{$[0>type x;x;enlist x]};

.aq.wildCard:{{x!x} cols x};

// load
.aq.load:{[fileh;sep;destnm]
  data:(upper exec t from meta destnm;enlist sep) 0:hsym fileh;
  destnm upsert data
  }
.aq.save:{[fileh;sep;t] fileh 0:sep 0:t};

.trg.allowedEvents:`insert`update`delete;
.trg.allowedTimings:`before`after;
.trg.defaultMode:{[timing] $[timing=`after;`log;`strict]};
.trg.registry:([]
  table:`symbol$();
  event:`symbol$();
  timing:`symbol$();
  name:`symbol$();
  priority:`int$();
  enabled:`boolean$();
  mode:`symbol$();
  funcSym:`symbol$()
  );
.trg.errors:([]
  ts:`timestamp$();
  name:`symbol$();
  table:`symbol$();
  event:`symbol$();
  timing:`symbol$();
  error:()
  );

.trg.emptyCode:{[x] $[10h=type x; 0=count x; 1b]};
.trg.symCode:{[x]
  $[-11h=type x;
      "`",string x;
      $[11h=type x;
          "`",("`" sv string x);
          string x
       ]
   ]
  };
.trg.targetCode:{[tbl;target]
  $[-11h=type target;
      string target;
      $[10h=type target;
          $[0=count target; string tbl; target];
          string tbl
       ]
   ]
  };
.trg.codeOr:{[x;d]
  $[10h=type x;
      $[0=count x; d; x];
      d
   ]
  };
.trg.kfunctional:{[verb;tableCode;whereCode;byCode;payloadCode]
  verb,"[",
    tableCode,";",
    .trg.codeOr[whereCode;"()"],";",
    .trg.codeOr[byCode;"0b"],";",
    .trg.codeOr[payloadCode;"()"],"]"
  };
.trg.kdbUpdateStmt:{[tbl;ctx]
  .trg.kfunctional["!"; .trg.targetCode[tbl;ctx`target]; ctx`where; ctx`by; ctx`set]
  };
.trg.kdbDeleteRowsStmt:{[tbl;ctx]
  .trg.kfunctional["!"; .trg.targetCode[tbl;ctx`target]; ctx`where; ""; "`$()"]
  };
.trg.kdbDeleteColsStmt:{[tbl;cols]
  .trg.kfunctional["!"; string tbl; ""; ""; .trg.symCode cols]
  };
.trg.scalar:{[x] $[0>type x; x; first x]};
.trg.evalArg:{[x]
  $[10h=type x; value x; x]
  };
.trg.asTable:{[x]
  $[98h=type x; x; 99h=type x; flip x; x]
  };
.trg.rowCount:{[x]
  t:type x;
  $[98h=t; count x; 99h=t; count first .Q.v x; count x]
  };
.trg.rowMatchIdx:{[tbl;row]
  tbl:.trg.asTable tbl;
  ks:key row;
  mask:(.trg.rowCount tbl)#1b;
  i:0;
  while[i<count ks;
    k:ks i;
    mask:mask & ((tbl k)=row k);
    i+:1
    ];
  where mask
  };
.trg.tableArg:{[tnm;target]
  if[98h=type target; :.trg.asTable target];
  if[99h=type target; :.trg.asTable target];
  if[-11h=type target; :.trg.asTable value string target];
  if[10h=type target;
    if[0=count target; :.trg.asTable value string tnm];
    :.trg.asTable value target
    ];
  .trg.asTable value string tnm
  };
.trg.whereIdx:{[tbl;w]
  tbl:.trg.asTable tbl;
  if[(0h=abs type w) & (1=count w); w:first w];
  n:.trg.rowCount tbl;
  t:type w;
  at:abs t;
  ati:"i"$at;
  if[(0h=at)&(0=count w); :til n];
  if[-1h=t; :$[w;til n;`long$()]];
  if[99h=at; :.trg.rowMatchIdx[tbl;w]];
  if[1h=at;
    if[(count w)<>n;'"boolean where length mismatch"];
    :where w
    ];
  if[ati in 6 7 8 9;
    :$[0>t; enlist w; w]
    ];
  '"unsupported where object"
  };
.trg.canApplyRowWhere:{[w]
  if[(0h=abs type w) & (1=count w); w:first w];
  t:type w;
  at:abs t;
  ati:"i"$at;
  $[(0h=at) & (0=count w); 1b; (-1h=t) | (1h=at) | (99h=at) | (ati in 6 7 8 9)]
  };
.trg.nativeWhereArg:{[tbl;w]
  tbl:.trg.asTable tbl;
  n:.trg.rowCount tbl;
  t:type w;
  at:abs t;
  ati:"i"$at;
  if[(0h=at)&(0=count w); :()];
  if[(0h=at)&(0<count w); :w];
  if[-1h=t; :w];
  if[1h=at;
    if[(count w)<>n;'"boolean where length mismatch"];
    :w
    ];
  if[99h=at;
    idx:.trg.rowMatchIdx[tbl;w];
    mask:n#0b;
    if[count idx; mask[idx]:1b];
    :mask
    ];
  if[ati in 6 7 8 9;
    idx:$[0>t; enlist w; w];
    mask:n#0b;
    if[count idx; mask[idx]:1b];
    :mask
    ];
  '"unsupported where object"
  };
.trg.dictKeys:{[d]
  k:key d;
  $[-11h=type k; enlist k; k]
  };
.trg.dictVals:{[d;ks]
  vals:value d;
  $[(count ks)=count vals; vals; enlist vals]
  };
.trg.expandForRows:{[m;v]
  t:type v;
  if[0>t; :m#v];
  if[0=m; :v];
  if[count v=m; :v];
  if[1=count v; :m#first v];
  '"update value length mismatch"
  };
.trg.singleSetPayload:{[k;v]
  (enlist k)!enlist v
  };
.trg.applyRowUpdate:{[tbl;whereObj;upd]
  tbl:.trg.asTable tbl;
  idx:.trg.whereIdx[tbl;whereObj];
  if[(count idx)=.trg.rowCount tbl;
    :.trg.applyNativeUpdate[tbl;();0b;upd]
    ];
  d:0!tbl;
  ks:.trg.dictKeys upd;
  vals:.trg.dictVals[upd;ks];
  i:0;
  while[i<count ks;
    k:ks i;
    v:vals i;
    col:d k;
    col[idx]:.trg.expandForRows[count idx;v];
    d[k]:col;
    i+:1
    ];
  .trg.asTable flip d
  };
.trg.applyRowDelete:{[tbl;whereObj]
  tbl:.trg.asTable tbl;
  mask:.trg.nativeWhereArg[tbl;whereObj];
  keep:not mask;
  if[all keep; :tbl];
  .trg.asTable ?[tbl;keep;0b;()]
  };
.trg.applyNativeUpdate:{[tbl;whereObj;byObj;upd]
  ks:.trg.dictKeys upd;
  whereArg:$[byObj~0b; .trg.nativeWhereArg[tbl;whereObj]; whereObj];
  res:.trg.asTable tbl;
  i:0;
  while[i<count ks;
    k:ks i;
    v:upd k;
    res:.trg.asTable ![res;whereArg;byObj;.trg.singleSetPayload[k;v]];
    i+:1
    ];
  res
  };
.trg.applyNativeDelete:{[tbl;whereObj]
  .trg.asTable ![.trg.asTable tbl;.trg.nativeWhereArg[tbl;whereObj];0b;`$()]
  };

.trg.logError:{[row;err]
  insert[`.trg.errors;(.z.p;.trg.scalar row`name;.trg.scalar row`table;.trg.scalar row`event;.trg.scalar row`timing;string err)];
  };
.trg.failHandler:{[row;err]
  .trg.logError[row;err];
  '"trigger failure"
  };
.trg.logHandler:{[row;ctx;err]
  .trg.logError[row;err];
  ctx
  };
.trg.invoke:{[row;ctx]
  tbl:.trg.scalar row`table;
  evt:.trg.scalar row`event;
  fn:value string .trg.scalar row`funcSym;
  fn[tbl;evt;ctx]
  };
.trg.run:{[tbl;evt;tim;ctx]
  tr:`priority xasc select from .trg.registry where enabled,table in (`*;tbl),event=evt,timing=tim;
  if[0=count tr; :ctx];
  acc:ctx;
  i:0;
  while[i<count tr;
    acc:.trg.invoke[tr i;acc];
    i+:1
    ];
  acc
  };

.trg.registerMode:{[tbl;evt;tim;nm;pri;md;fn]
  if[not evt in .trg.allowedEvents;'"unsupported trigger event"];
  if[not tim in .trg.allowedTimings;'"unsupported trigger timing"];
  if[not md in `strict`log;'"unsupported trigger mode"];
  if[nm in .trg.registry`name;'"trigger already exists"];
  fs:$[-11h=type fn;fn;' "trigger function must be passed as a symbol"];
  insert[`.trg.registry;(tbl;evt;tim;nm;pri;1b;md;fs)];
  nm
  };
.trg.register:{[tbl;evt;tim;nm;pri;fn]
  .trg.registerMode[tbl;evt;tim;nm;pri;.trg.defaultMode tim;fn]
  };
.trg.enable:{[nm]
  .trg.registry:update enabled:1b from .trg.registry where name=nm;
  nm
  };
.trg.disable:{[nm]
  .trg.registry:update enabled:0b from .trg.registry where name=nm;
  nm
  };
.trg.drop:{[nm]
  if[not nm in .trg.registry`name;'"trigger does not exist"];
  .trg.registry:delete from .trg.registry where name=nm;
  nm
  };
.trg.on:{[tbl;evt;tim;nm;fn]
  .trg.register[tbl;evt;tim;nm;100;fn]
  };
.trg.onP:{[tbl;evt;tim;nm;pri;fn]
  .trg.register[tbl;evt;tim;nm;pri;fn]
  };
.trg.beforeInsert:{[tbl;nm;fn]
  .trg.on[tbl;`insert;`before;nm;fn]
  };
.trg.beforeInsertP:{[tbl;nm;pri;fn]
  .trg.onP[tbl;`insert;`before;nm;pri;fn]
  };
.trg.afterInsert:{[tbl;nm;fn]
  .trg.on[tbl;`insert;`after;nm;fn]
  };
.trg.afterInsertP:{[tbl;nm;pri;fn]
  .trg.onP[tbl;`insert;`after;nm;pri;fn]
  };
.trg.beforeUpdate:{[tbl;nm;fn]
  .trg.on[tbl;`update;`before;nm;fn]
  };
.trg.beforeUpdateP:{[tbl;nm;pri;fn]
  .trg.onP[tbl;`update;`before;nm;pri;fn]
  };
.trg.afterUpdate:{[tbl;nm;fn]
  .trg.on[tbl;`update;`after;nm;fn]
  };
.trg.afterUpdateP:{[tbl;nm;pri;fn]
  .trg.onP[tbl;`update;`after;nm;pri;fn]
  };
.trg.beforeDelete:{[tbl;nm;fn]
  .trg.on[tbl;`delete;`before;nm;fn]
  };
.trg.beforeDeleteP:{[tbl;nm;pri;fn]
  .trg.onP[tbl;`delete;`before;nm;pri;fn]
  };
.trg.afterDelete:{[tbl;nm;fn]
  .trg.on[tbl;`delete;`after;nm;fn]
  };
.trg.afterDeleteP:{[tbl;nm;pri;fn]
  .trg.onP[tbl;`delete;`after;nm;pri;fn]
  };
.trg.ctxHas:{[ctx;k]
  k in key ctx
  };
.trg.ctxGet:{[ctx;k;d]
  $[.trg.ctxHas[ctx;k]; ctx k; d]
  };
.trg.ctxSet:{[ctx;k;v]
  ks:key ctx;
  vals:value ctx;
  ix:ks?k;
  if[ix<count ks;
    vals[ix]:v;
    :(ks!vals)
    ];
  (ks,enlist k)!(vals,enlist v)
  };
.trg.rows:{[ctx]
  .trg.ctxGet[ctx;`rows;()]
  };
.trg.oldRows:{[ctx]
  .trg.ctxGet[ctx;`oldRows;()]
  };
.trg.resultRows:{[ctx]
  .trg.ctxGet[ctx;`result;()]
  };
.trg.target:{[ctx]
  .trg.ctxGet[ctx;`target;`]
  };
.trg.modifier:{[ctx]
  .trg.ctxGet[ctx;`modifier;`symbol$()]
  };
.trg.whereArg:{[ctx]
  .trg.ctxGet[ctx;`where;()]
  };
.trg.byArg:{[ctx]
  .trg.ctxGet[ctx;`by;0b]
  };
.trg.setArg:{[ctx]
  .trg.ctxGet[ctx;`set;()]
  };
.trg.withRows:{[ctx;rows]
  .trg.ctxSet[ctx;`rows;rows]
  };
.trg.withResult:{[ctx;result]
  .trg.ctxSet[ctx;`result;result]
  };
.trg.sourceRows:{[tbl;whereObj]
  .trg.asTable ?[.trg.asTable tbl;.trg.nativeWhereArg[tbl;whereObj];0b;()]
  };
.trg.affectedResultRows:{[ctx]
  if[not .trg.ctxHas[ctx;`result]; :()];
  result:.trg.resultRows ctx;
  .trg.asTable ?[result;.trg.nativeWhereArg[result;.trg.whereArg ctx];0b;()]
  };
.trg.upsertRows:{[dest;rows]
  if[0=count rows; :rows];
  dest upsert rows
  };
.trg.syncInsertRowsTo:{[ctx;dest;rowFn]
  if[not .trg.ctxHas[ctx;`rows]; :ctx];
  rows:.trg.rows ctx;
  if[0<count rows;
    rows:rowFn rows;
    .trg.upsertRows[dest;rows]
    ];
  ctx
  };
.trg.syncUpdateRowsTo:{[ctx;dest;rowFn]
  rows:.trg.affectedResultRows ctx;
  if[0<count rows;
    rows:rowFn rows;
    .trg.upsertRows[dest;rows]
    ];
  ctx
  };
.trg.syncMappedUpdateRowsTo:{[rows;dest;destKeys;srcKeys;colMap]
  rows:.trg.asTable rows;
  if[0=count rows; :value dest];
  dt:.trg.asTable value dest;
  dks:$[-11h=type destKeys; enlist destKeys; destKeys];
  sks:$[-11h=type srcKeys; enlist srcKeys; srcKeys];
  destCols:.trg.dictKeys colMap;
  srcCols:.trg.dictVals[colMap;destCols];
  i:0;
  while[i<count rows;
    r:rows i;
    mask:(.trg.rowCount dt)#1b;
    j:0;
    while[j<count dks;
      mask:mask & ((dt (dks j))=r (sks j));
      j+:1
      ];
    idx:where mask;
    if[count idx;
      k:0;
      while[k<count destCols;
        dc:destCols k;
        sc:srcCols k;
        col:dt dc;
        col[idx]:count[idx]#r sc;
        dt[dc]:col;
        k+:1
        ]
      ];
    i+:1
    ];
  dest set dt;
  dt
  };
.trg.syncMappedDeleteRowsFrom:{[rows;dest;destKeys;srcKeys]
  rows:.trg.asTable rows;
  if[0=count rows; :value dest];
  dt:.trg.asTable value dest;
  dks:$[-11h=type destKeys; enlist destKeys; destKeys];
  sks:$[-11h=type srcKeys; enlist srcKeys; srcKeys];
  keep:(.trg.rowCount dt)#1b;
  i:0;
  while[i<count rows;
    r:rows i;
    mask:(.trg.rowCount dt)#1b;
    j:0;
    while[j<count dks;
      mask:mask & ((dt (dks j))=r (sks j));
      j+:1
      ];
    idx:where mask;
    if[count idx; keep[idx]:count[idx]#0b];
    i+:1
    ];
  dt:?[dt;keep;0b;()];
  dest set dt;
  dt
  };
.trg.syncDeleteRowsFrom:{[ctx;dest;keyCol]
  rows:.trg.affectedResultRows ctx;
  if[0=count rows; :ctx];
  if[98h<>type rows; :ctx];
  delKeys:rows[keyCol];
  dt:value dest;
  if[99h=type dt;
    if[not keyCol in key dt;'"delete sync key column missing in keyed destination"];
    dest set keyCol xkey (delete from value dt where (keyCol in delKeys));
    :ctx
    ];
  dest set delete from dt where (keyCol in delKeys);
  ctx
  };

.aq.insert:{[tnm;sorted;modifier;src]
  ctnm:cols tnm;
  if[(0 < count modifier) & (98>type src) & count[modifier]<>count src;'"insert values do not match stated cols"];
  l:$[0 < count modifier; modifier; ctnm];
  d:$[98<=type src;
      $[0<count modifier;
        $[modifier~cols src;src;flip (modifier!value flip src)];
        l xcol src];
      l!src];
  ictx:(`rows`modifier`target)!(d;modifier;tnm);
  ictx:.trg.run[tnm;`insert;`before;ictx];
  if[99h<>type ictx;'"insert trigger must return dictionary context"];
  if[not `rows in key ictx;'"insert trigger context must contain `rows"];
  d:ictx`rows;
  assigned:tnm upsert d;
  result:.trg.asTable value string tnm;
  if[((-11h=type sorted) | (10h=type sorted));
    sortedValue:.trg.asTable value sorted;
    result:sortedValue upsert d;
    assigned:tnm set result
    ];
  .trg.run[tnm;`insert;`after;(`rows`modifier`target`result)!(ictx`rows;ictx`modifier;ictx`target;result)];
  assigned
  };

.aq.update:{[tnm;target;whereCode;byCode;setCode]
  uctx:(`target`where`by`set)!(target;whereCode;byCode;setCode);
  tbl0:.trg.tableArg[tnm;uctx`target];
  whereObj0:.trg.evalArg uctx`where;
  oldRows:.trg.sourceRows[tbl0;whereObj0];
  uctx:.trg.run[tnm;`update;`before;(`target`where`by`set`oldRows)!(uctx`target;uctx`where;uctx`by;uctx`set;oldRows)];
  if[99h<>type uctx;'"update trigger must return dictionary context"];
  tbl:.trg.tableArg[tnm;uctx`target];
  whereObj:.trg.evalArg uctx`where;
  byObj:.trg.evalArg uctx`by;
  upd:.trg.evalArg uctx`set;
  result:$[(byObj~0b) & .trg.canApplyRowWhere whereObj;
    .trg.applyRowUpdate[tbl;whereObj;upd];
    .trg.applyNativeUpdate[tbl;whereObj;byObj;upd]
    ];
  assigned:tnm set result;
  .trg.run[tnm;`update;`after;(`target`where`by`set`result`oldRows)!(uctx`target;uctx`where;uctx`by;uctx`set;result;oldRows)];
  assigned
  };

.aq.deleteRows:{[tnm;target;whereCode]
  dctx:(`target`where)!(target;whereCode);
  tbl0:.trg.tableArg[tnm;dctx`target];
  whereObj0:.trg.evalArg dctx`where;
  oldRows:.trg.sourceRows[tbl0;whereObj0];
  dctx:.trg.run[tnm;`delete;`before;(`target`where`oldRows)!(dctx`target;dctx`where;oldRows)];
  if[99h<>type dctx;'"delete trigger must return dictionary context"];
  tbl:.trg.tableArg[tnm;dctx`target];
  whereObj:.trg.evalArg dctx`where;
  result:.trg.applyNativeDelete[tbl;whereObj];
  assigned:tnm set result;
  .trg.run[tnm;`delete;`after;(`target`where`result`oldRows)!(dctx`target;dctx`where;result;oldRows)];
  assigned
  };

.aq.deleteCols:{[tnm;dropCols]
  keep:(cols tnm) except dropCols;
  tnm set ?[tnm;();0b;keep!keep]
  };

.trg.enrichTrade:{[tbl;event;ctx]
  if[(tbl=`trade)&(event=`insert)&.trg.ctxHas[ctx;`rows];
    rows:.trg.rows ctx;
    if[98h=type rows;
      if[all `price`qty in cols rows;
        price:rows`price;
        qty:rows`qty;
        rows:flip `sym`price`qty`value`ts!(
          rows`sym;
          price;
          qty;
          price*qty;
          (count rows)#.z.p
          )
        ]
      ];
    :.trg.withRows[ctx;rows]
    ];
  ctx
  };
.trg.auditTrade:{[tbl;event;ctx]
  if[(tbl=`trade)&(event in `insert`update`delete);
    if[not `tradeLog in key `.;
      tradeLog:flip `ts`event`table`payload!(
        enlist .z.p;
        enlist `init;
        enlist tbl;
        enlist (enlist `sample)
        );
      tradeLog:0#tradeLog
      ];
    insert[`tradeLog;(.z.p;event;tbl;ctx)]
    ];
  ctx
  };
.trg.reset:{
  .trg.registry:0#.trg.registry;
  .trg.errors:0#.trg.errors;
  };
.trg.selftest:{
  .trg.reset[];
  `ok`registry`errors!(1b;count .trg.registry;count .trg.errors)
  };

// case expression
.aq.else:{$[0=count x;first 0#y;x]};
// explicit conditions
.aq.eCond:{[ct;e] ?[ct[0;0]; ct[0;1]; $[1=count ct; .aq.else[e; ct[0;1]]; .z.s[1_ct;e]]]};
// implicit conditions
.aq.searchedCond:{[v;ct;e] .aq.eCond[flip (eval each (=;v; ) each first fct; last fct:flip ct); e]};
// wrapper
.aq.cond:{[v;ct;e] $[0=count v; .aq.eCond[ct;e]; .aq.searchedCond[v;ct;e]]}


// Builtins
// Overloaded built-ins are disambiguated by appending the number of arguments
// This precludes overloads with same number of args but different argument types If this is desired
// then it has to be handled at runtime.
.aq.abs:abs;
.aq.and:min;
.aq.avg:avg;
.aq.avgs1:avgs;
.aq.avgs2:mavg;
.aq.between:{x within (y;z)};
.aq.concatenate:(upsert/);
.aq.count:count;
.aq.deltas:deltas;
.aq.distinct:distinct;
.aq.drop:_;
.aq.list:{$[0<=type x;x;enlist x]};
.aq.exec_arrays:{show {key[x] set'value x}flip 0!x;x};
.aq.flatten:ungroup;
.aq.fill:^;
.aq.first1:first;
.aq.first2:sublist;
.aq.is:(::);
.aq.in:in;
.aq.indexEven:{x where (count x)#10b};
.aq.indexOdd:{x where (count x)#01b};
.aq.indexEveryN:{y where $[0>=x;();(count y)#((x-1)#0b),1b]};
.aq.last1:last;
.aq.last2:{[x;y] neg[x] sublist y};
.aq.like:{[x;y] x like string y};
.aq.makeNull:first 0#;
.aq.max:max;
.aq.maxs1:maxs;
.aq.maxs2:mmax;
.aq.min:min;
.aq.mins1:mins;
.aq.mins2:mmin;
.aq.mod:mod;
.aq.moving:{[f;w;a] f each {(x sublist y),z}[1-w;;]\[a]};
.aq.neg:neg;
.aq.next1:next;
.aq.next2:{(neg x) xprev y};
.aq.not:not;
.aq.null:null;
.aq.or:max;
.aq.overlaps:{[x;y] not (x[1]<y[0])|y[1]<x[0]};
.aq.pow:xexp;
.aq.prev1:prev;
.aq.prev2:xprev;
.aq.prd:prd;
.aq.prds:prds;
.aq.ratios:{[x;y] y%x xprev y};
.aq.reverse:reverse;
.aq.show:show;
.aq.sum:sum;
.aq.sums1:sums;
.aq.sums2:msum;
.aq.sqrt:sqrt;
.aq.stddev:dev;
.aq.toSym:`$;
.aq.vars:{mavg[x;y*y]-m*m:mavg[x;y:"f"$y]};
// Translation begins here
.aq.show `lineitem set ([]l_orderkey:"j"$();l_partkey:"j"$();l_suppkey:"j"$();l_linenumber:"j"$();l_quantity:"f"$();l_extendedprice:"f"$();l_discount:"f"$();l_tax:"f"$();l_returnflag:"s"$();l_linestatus:"s"$();l_shipdate:"s"$();l_commitdate:"s"$();l_receiptdate:"s"$();l_shipinstruct:"s"$();l_shipmode:"s"$();l_comment:"s"$());

.aq.show .aq.load[hsym `$"/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/tpch/data_sf2/lineitem.tbl";"|";`lineitem];

.aq.show `orders set ([]o_orderkey:"j"$();o_custkey:"j"$();o_orderstatus:"s"$();o_totalprice:"f"$();o_orderdate:"s"$();o_orderpriority:"s"$();o_clerk:"s"$();o_shippriority:"j"$();o_comment:"s"$());

.aq.show .aq.load[hsym `$"/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/tpch/data_sf2/orders.tbl";"|";`orders];
