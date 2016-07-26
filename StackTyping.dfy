
include "Prelude.dfy"
include "Common.dfy"
include "StackSyntax.dfy"

function method TypeValue(v: value): Type {
  match v
    case integer(_) => Int
    case boolean(_) => Bool
    case unit       => Unit
}

function method TypeOperation(o: operation): (Sigma, Type) {
  match o
    case not => ([Bool], Bool)
    case read(t) => ([], t)
    case printf(format) => (SeqFromList(Lefts(format)), Unit)
    case const(v) =>
      match v {
        case integer(_) => ([], Int)
        case boolean(_) => ([], Bool)
        case unit       => ([], Unit)
      }
    case binary(o) =>
      match o
        case BoolOp(_) => ([Bool, Bool], Bool)
        case RelOp(_)  => ([Int, Int],   Bool)
        case MathOp(_) => ([Int, Int],   Int)
}

function method TypeCommand(c: command, S: Sigma): Maybe<Sigma> {
  match c
    case store(n) =>
      if n < |S| && S != []
        then Just(S[n := S[n]])
        else Nothing
    case load(n) =>
      if n < |S|
        then Just([S[n]] + S)
        else Nothing
    case pop(n) =>
      if n <= |S|
        then Just(S[n ..])
        else Nothing
    case apply(n, o) =>
      if n <= |S|
        then var S'  := S[.. n];
             var S'' := S[n ..];
             var (So, t) := TypeOperation(o);
             if S' == So
               then Just([t] + S'')
               else Nothing
        else Nothing
}

function method TypeCommands(cs: List<command>, S: Sigma): Maybe<Sigma>
  decreases cs
{
  match cs
    case Nil => Just(S)
    case Cons(c, cs) =>
      BindMaybe(TypeCommand(c, S), S' => TypeCommands(cs, S'))
}

function method Split<A>(n: nat, v: seq<A>): (seq<A>, seq<A>)
  requires n <= |v|
  ensures var (xs, ys) := Split(n, v); |xs| == n && |ys| == |v| - n
{
  var xs := v[.. n];
  var ys := v[n ..];
  (xs, ys)
}

function method Uncons<A>(v: seq<A>): (A, seq<A>)
  requires 0 < |v|
  ensures |Uncons(v).1| == |v| - 1
{
  var (xs, ys) := Split(1, v);
  (xs[0], ys)
}

predicate method Prefix<A(==)>(s: seq<A>, t: seq<A>) {
  |s| <= |t| &&
    forall i | 0 <= i < |s| :: s[i] == t[i]
}

lemma PrefixReflexive<A(==)>(s: seq<A>)
  ensures Prefix(s, s)
{
}

lemma PrefixAntisymmetric<A(==)>(s: seq<A>, t: seq<A>)
  requires Prefix(s, t)
  requires Prefix(t, s)
  ensures s == t
{
}

lemma PrefixTransitive<A(==)>(r: seq<A>, s: seq<A>, t: seq<A>)
  requires Prefix(r, s)
  requires Prefix(s, t)
  ensures  Prefix(r, t)
{
}

predicate method SubPhi(s: Phi, t: Phi) {
  var (s, t) := (s.out, t.out);
  |s| <= |t| &&
    forall i | 0 <= i < |s| ::
      SubPhi(s[i].0, t[i].0) &&
      Prefix(s[i].1, t[i].1)
}

lemma SubPhiReflexive(s: Phi)
  ensures SubPhi(s, s)
{
}

lemma SubPhiTransitive(r: Phi, s: Phi, t: Phi)
  requires SubPhi(r, s)
  requires SubPhi(s, t)
  ensures  SubPhi(r, t)
{
}

predicate method TypeJump(D: Delta, SigmaH: Sigma, j: jump, P: Phi) {
  match j
    case goto(n) =>
      n in D && SubPhi(D[n], P)
    case halt =>
      0 < |P.out| &&
      var ((PhiR', SigmaH'), Phi_rest) := Uncons(P.out);
      Prefix(SigmaH, SigmaH')
    case branch(n1, n2) =>
      0 < |P.out| &&
      n1 in D && n2 in D &&
      var ((PhiR, S), Phi_rest) := Uncons(P.out);
      S != [] &&
      var (t, S') := Uncons(S);
      t == Bool &&
      var P' := Phi([(PhiR, S')] + Phi_rest);
      SubPhi(D[n1], P') && SubPhi(D[n2], P')
    case call(n, nJ, nR) =>
      0 < |P.out| &&
      nJ in D && nR in D &&
      var ((PhiR, S), Phi_rest) := Uncons(P.out);
      n < |S| &&
      var (S1, S2) := Split(n, S);
      SubPhi(D[nJ], Phi([(D[nR], S1), (PhiR, S2)] + Phi_rest))
    case ret(n) =>
      |P.out| >= 2 &&
      var ((PhiR_now, SS), Phi_rest) := Uncons(P.out);
      n <= |SS| &&
      var (S_check, S_nope) := Split(n, SS);
      var ((PhiR,  S),  Phi_rest')  := Uncons(Phi_rest);
      SubPhi(PhiR_now, Phi([(PhiR, S_check + S)] + Phi_rest'))
}

predicate method TypeBlock(D: Delta, SigmaH: Sigma, b: block, P: Phi) {
  var (cs, j) := b;
  0 < |P.out| &&
  var ((PhiR, S), P_rest) := Uncons(P.out);
  match TypeCommands(cs, S)
    case Nothing => false
    case Just(S_final) => TypeJump(D, SigmaH, j, Phi([(PhiR, S_final)] + P_rest))
}

lemma TypeCommandExpansion(c: command, S1: Sigma, S1_out: Sigma, S2: Sigma)
  requires Prefix(S1, S2)
  requires TypeCommand(c, S1) == Just(S1_out)
  ensures  exists S2_out :: TypeCommand(c, S2) == Just(S2_out)
{
}

lemma TypeCommandPrefixPreservation(c: command, S1: Sigma, S2: Sigma, S1': Sigma, S2': Sigma)
  requires Prefix(S1, S2)
  requires TypeCommand(c, S1) == Just(S1')
  requires TypeCommand(c, S2) == Just(S2')
  ensures  Prefix(S1', S2')
{
}

lemma TypeCommandsExpansion(cs: List<command>, S1: Sigma, S1_out: Sigma, S2: Sigma)
  requires Prefix(S1, S2)
  requires TypeCommands(cs, S1) == Just(S1_out)
  ensures  exists S2_out :: TypeCommands(cs, S2) == Just(S2_out) && Prefix(S1_out, S2_out)
{
  match cs
    case Nil =>
    case Cons(c, cs) =>
      var S1' := TypeCommand(c, S1).FromJust;
      var S2' := TypeCommand(c, S2).FromJust;
      TypeCommandExpansion(c, S1, S1', S2);
      TypeCommandsExpansion(cs, S1', S1_out, S2');
}

lemma TypeBlockExpansion(D: Delta, SigmaH: Sigma, b: block, P: Phi, P': Phi)
  requires TypeBlock(D, SigmaH, b, P)
  requires SubPhi(P, P')
  ensures  TypeBlock(D, SigmaH, b, P')
{
  var (cs, j) := b;
  var ((PhiR, S), P_rest) := Uncons(P.out);
  var ((PhiR', S'), P_rest') := Uncons(P'.out);
  match TypeCommands(cs, S)
    case Just(S_final) =>
      TypeCommandsExpansion(cs, S, S_final, S');
      var S_final' := TypeCommands(cs, S').FromJust;
      match j
        case goto(n) =>
          SubPhiTransitive(D[n], Phi([(PhiR, S_final)] + P_rest), Phi([(PhiR', S_final')] + P_rest'));
        case halt =>
        case branch(n1, n2) =>
          var (_, S_final)  := Uncons(S_final);
          var (_, S_final') := Uncons(S_final');
          SubPhiTransitive(D[n1], Phi([(PhiR, S_final)] + P_rest), Phi([(PhiR', S_final')] + P_rest'));
          SubPhiTransitive(D[n2], Phi([(PhiR, S_final)] + P_rest), Phi([(PhiR', S_final')] + P_rest'));
        case call(n, nj, nr) =>
          var (S1, S2)   := Split(n, S);
          var (S1', S2') := Split(n, S');
          SubPhiTransitive(D[nJ], Phi([(D[nR], S1), (PhiR, S2)] + Phi_rest), Phi([(D[nR], S1'), (PhiR', S2')] + Phi_rest'));
        case ret(n) =>
}

// What I want:
//    - pattern matching on sequences using literal and slice notation
//    - non-linear patterns?
//    - maybe something like "if pat := exp then ... else ..."? or case defaults?
//    From these, we get the ability to succinctly match against structure that we need.
