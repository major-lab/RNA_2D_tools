#mask functions
# - destroy percentage of a mask


function isRNA{S<:String}(seq::S)
  #verifies that the sequence is RNA
  #accepts T
  seq = uppercase(seq)
  for nt in seq
    if !(nt in ['A','T','C','G','U'])
      return false
    end
  end
  return true
end


function isBalancedMask{S<:String}(mask::S)
  #verifies that the given mask is balanced
  #format is :
  #           'x' -> unknown
  #           '.' -> unpaired
  #    '(' or ')' -> paired
  count = 0
  for info in mask
    if info == '('
      count += 1
    elseif info == ')'
      count -= 1
    elseif info != 'x'
      return false
    end

    if count < 0
      return false
    end
  end

  if count != 0
    return false
  else
    return true
  end
end


function destroyNonCanonicalFromMask{S <: String}(balancedMask::S, RNAsequence::S)
  #removes non canonical base pairs from the mask
  @assert isRNA(RNAsequence) == true
  @assert isBalancedMask(mask) == true
  @assert length(balancedMas) == length(RNAsequence)

  function isCanonical(a,b)
    #checks if the base pair is canonical or not
    if a == 'T' || a == 't'
      a = 'U'
    elseif b == 'T' || b == 't'
      b = 'U'
    end
    pair = [uppercase(a), uppercase(b)]
    sort!(pair)
    pair = (pair[1], pair[2])
    pair in [('A', 'U'), ('C','G')]
  end

  paired = (Int,Int)[]
  unpaired = Int[]
  openingPair = Int[]
  for (i, info) in enumerate(balancedMask)
    if info == '('
      push!(openingPair, i)
    elseif info == ')'
      opening = pop!(openingPair)
      if isCanonical(RNAsequence[opening], RNAsequence[i])
        push!(paired, (opening, i))
      end
    elseif info == '.'
      push!(unpaired, i)
    end
  end
  
  resultMask = Char[]
  for i = 1:length(balancedMask)
    push!(resultMask, 'x')
  end
  for i in unpaired
    resultMask[i] = '.'
  end
  for (i,j) in paired
    resultMask[i] = '('
    resultMask[j] = ')'
  end
  CharString(resultMask)
end



function percentageBalancedMask{S<:String}(balancedMask::S, percentage::FloatingPoint)
  #separates the information in the mask by paired or unpaired types
  #destroys a portion of it randomly (depending on given percentage)
  #the percentage is the floor of percentage * length(paired)
  #                               percentage * length(unpaired)
  #this technique was used in the RNA folding benchmark
  @assert  0 <= percentage <= 1
  @assert isBalancedMask(balancedMask) == true
  paired = (Int, Int)[]
  unpaired = Int[]
  openingPair = Int[]

  for (i, info) in enumerate(balancedMask)
    if info == '.'
      push!(unpaired, i)
    elseif info == '('
      push!(openingPair, i)
    elseif info == ')'
      push!(paired, (pop!(openingPair, i)))
    end
  end

  shuffle!(paired)
  shuffle!(unpaired)

  toKeepPaired = floor(percentage * length(paired))
  toKeepUnpaired = floor(percentage * length(unpaired))

  if toKeepPaired == 0
    paired = []
  else
    paired = paired[1:toKeepPaired]
  end
  if toKeepUnpaired == 0
    unpaired = []
  else
    unpaired = unpaired[1:toKeepUnpaired]
  end
  
  resultMask = Char[]
  for i = 1:length(balancedMask)
    push!(resultMask, 'x')
  end
  for i in unpaired
    resultMask[i] = '.'
  end
  for (i,j) in paired
    resultMask[i] = '('
    resultMask[j] = ')'
  end
  CharString(resultMask)
end



# function conciliateUnbalancedMask{S<:String}(unbalancedMask1::S, unbalancedMask2::S)
#   #as implemented in flashfold (by Paul Dallaire)
#   #conciliates or returns an error
#   @assert length(masks1) == length(masks2)
#   for sym in collect(unbalancedMask1)
#     @assert sym in keys(symbols)
#   end
# 
#   for sym in collect(unbalancedMask2)
#     @assert sym in keys(symbols)
#   end
# 
#   const symbols = { #should make this an enum really
#     ')' => 1,
#     '(' => 2,
#     '.' => 3,
#     'x' => 4,
#     '|' => 5,
#     '-' => 6,
#     '[' => 7,
#     ']' => 8,
#     '+' => 9,
#     '_' => 10,
#     '<' => 11,
#     '>' => 12,
#     '!' => 13,
#     'p' => 14,
#     'q' => 15
#   }
# 
#   const conciliationMatrix = Array[
#   #this is copied from flashfold C script
#   # warning : Julia is row-major (and 1-based, but that's been fixed)
#   #)  (  .  x  |  -  [  ]  +  _  <  >  !  p  q 
#   #1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
#   [ 1,-1,-1, 1, 1,12,-1, 8, 8, 8,-1,12,-1,-1, 1], # ) 1   reverse paired
#   [-1, 2,-1, 2, 2,11, 7,-1, 7, 7,11,-1,-1, 2,-1], # ( 2   forward paired
#   [-1,-1, 3, 3,-1, 6,-1,-1,-1,10,-1,-1,-1, 3, 3], # . 3   unpaired
#   [ 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15], # x 4   don't care
#   [ 1, 2,-1, 5, 5,13, 7, 8, 9, 9,11,12,13,14,15], # | 5   paired
#   [12,11, 6, 6,13, 6,-1,-1,-1, 3,11,12,13,-1,-1], # - 6   not canonically paired
#   [-1, 7,-1, 7, 7,-1, 7,-1, 7, 7,-1,-1,-1, 7,-1], # [ 7   forward canonically paired
#   [ 8,-1,-1, 8, 8,-1,-1, 8, 8, 8,-1,-1,-1,-1, 8], # ] 8   reverse canonically paired
#   [ 8, 7,-1, 9, 9,-1, 7, 8, 9, 9,-1,-1,-1,-1,-1], # + 9   canonically paired
#   [ 8, 7,10,10, 5, 3, 7, 8, 9,10,-1,-1,-1,-1,-1], # _ 10  not (paired non canonically)
#   [-1,11,-1,11,11,11,-1,-1,-1,-1,11,-1,11,11,-1], # < 11  forward paired non canonically
#   [12,-1,-1,12,12,12,-1,-1,-1,-1,-1,12,12,-1,12], # > 12  reverse paired non canonically
#   [12,11,-1,13,13,13,-1,-1,-1,-1,11,12,13,-1,-1], # ! 13  paired non canonically
#   [-1, 2, 3,14,14,-1, 7,-1,-1,-1,11,-1,-1,14,-1], # p 14  not reverse paired
#   [ 1,-1, 3,15,15,-1,-1, 8,-1,-1,-1,12,-1,-1,15]  # q 15  not forward paired
#   ]
# 
#   unbalancedMask1 = map(x->symbols[x], collect(unbalancedMask1))
#   unbalancedMask2 = map(x->symbols[x], collect(unbalancedMask2))
#   for i = 1:length(unbalancedMask1) #conciliate the masks
#     unbalancedMask1[i] = conciliationMatrix[unbalancedMask2[i]][conciliatedMask1[i]]
#   end
# 
# 
# 
# end
# 
# # void conciliate_full_masks( int seqLen, char *bmask, char *umask ){ //b:balanced, u:unbalanced
# #     if( NULL == bmask ){
# #         return;
# #     }
# #     
# #     int errors = 0;
# #     char bad_positions[ seqLen +1 ];
# #     bad_positions[seqLen] = 0;
# #     
# #     char * bmask_orig = strdup( bmask );
# #     char * umask_orig = strdup( umask );
# #     
# #     for( int i=0; i< seqLen; ++i ){
# # 
# #         bad_positions[i]=' ';
# #         
# #         int f  = symbol2idx( bmask[i] );
# #         int ub = symbol2idx( umask[i] );
# #         
# #         
# #         if( f < 0 ){
# #             fprintf(stderr, "ERROR: Unknown symbol (%c) in full mask.\n", bmask[i]);
# #             exit(ABORT_EXIT);
# #         }
# #         if( ub < 0 ){
# #             fprintf(stderr, "ERROR: Unknown symbol (%c) in full unbalanced mask.\n", umask[i]);
# #             exit(ABORT_EXIT);
# #         }
# #         
# #         int concil = CONCILIATION_MATRIX[ f + (NUMBER_OF_ALLOWED_MASK_SYMBOLS * ub) ];
# #         if( concil < 0 ){
# #             ++errors;
# #             bad_positions[i]='^';
# #         } else {
# #             umask[i] = allowedMaskSymbols[ concil ];
# #             if( f > symbol2idx(DONTCARESYM) ){
# #                 bmask[i] = DONTCARESYM;
# #             }
# #         }
# #     }
# #     if( errors > 0 ){
# #         fprintf(stderr,"ERROR: Can not reconcile %i constraint(s) from -m with those from -um.\n%s\n%s\n%s\n",
# #                 errors,
# #                 bmask_orig,
# #                 umask_orig,
# #                 bad_positions);
# #         exit(ABORT_EXIT);
# #     }
# #     free (umask_orig);
# #     free (bmask_orig);
# }

