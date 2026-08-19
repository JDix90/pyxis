# DIRECTIVE 9 — prose draft (Horizon 8 commit 0)

**Status: DRAFT FOR REVIEW. No code exists yet, deliberately.** Same gate the
UNSOUNDED fragments went through (§91) and for the same reason: prose is cheap
before the wiring exists and expensive after. Read it aloud. Veto freely. Four
decisions are marked **R1–R4** and want an answer rather than a nod.

---

## The finding that reshaped this

The plan was "the GSA's broadcasts change register once the player knows." Then
I read the table, and the table already answers.

`BROADCASTS` bands 1–4 are the Galactic Survey Authority speaking: an automated
beacon, a relay, a degraded relay, and then a carrier tone with nothing behind
it. Every one of them is **a recording**. And THE LAST RETURN's final entry —
already written, already shipped — says:

> *THE ENGINES WERE NOT RECALLED. THE WARDENS WERE NOT STOOD DOWN. SOMEBODY
> DECIDED THE MACHINES DID NOT NEED TO KNOW.*

So the authority's voice **cannot change**, and must not. The chart-edge beacon
goes on telling a commissioned pilot *"the bearing is yours, and it is written
down"* forever, in the same warm register, because it is a machine that was
never told. That line is already the most frightening sentence in the game; it
just needs a reader who has seen the order.

**What changes is everything that is alive.** Two voices out past the Quiet
that were never the GSA's, the player's own file, and the player's own ship.

This is cheaper than the original pitch, and it is better. It also means the
pass has a rule it can be held to: *if a recording changed its words, the pass
is wrong.*

---

## The gate

Directive 9 is fragment 2 of THE LAST RETURN — the bearing terminus, PYX-03,
past 5,200u. The register turns on **holding that specific fragment**, derived
from the data rather than hardcoded to a system:

```
knows_directive_9() := any deep_logs key ending ":return" with stage >= 2
```

Zero new save. It reads the v23 store §91 already ships, so a pilot who has
read it is already carrying the flag and does not need to re-earn it.

Fragment **3** of the same record — *"file a return for us"* — is a second rung
and is **not spent here**. It is the request that a later verb answers, and
offering that verb in the same breath as the revelation would turn a discovery
into a quest step. See §64's deferred row.

**R1 — is one record the right gate?** The alternative is all three archives
(nine fragments, three systems, ~45 minutes of outbound flying). I recommend
one: the reveal should be *reachable* by a player who mounts one real
expedition, and the other two archives are already what make it make sense.

---

## A. The two living voices

Bands 5 and 6 are the only broadcasts in the game that are not the authority.
Neither carries a `commissioned` variant, deliberately — *"being known by the
authority is not what gets you spoken to out here. Arriving is."* They gain an
after-register instead, on the same optional-key-with-fallback shape
`broadcast_for` already uses.

They are heard on the **next outward crossing**, which needs no work at all:
`_tick_broadcast` reads at fire time and caches nowhere. You learn the order at
the end of the world, fly home, and the deep says something different the next
time you go out.

### Band 5 — A KEPT LIGHT

Shipped, unchanged for a pilot who has not read the order:

> **A KEPT LIGHT** — *There is a light ahead of you. It is kept. It has been
> kept a long time, and by somebody. If you need it, it is there.*

After:

> **A KEPT LIGHT** — *The light ahead of you is kept by crews who were ordered
> not to come back. They came back anyway, and it did not count, so they stopped
> going home. It is still lit. It is lit for whoever is still out here, which
> now includes you.*

### Band 6 — · · ·

Shipped:

> **· · ·** — *Nothing is transmitting. Something is listening.*

After:

> **· · ·** — *Nothing is transmitting. Something is listening: a recorder, left
> running, taking down returns for a file that was closed a long time ago. It
> has your bearing. It will keep it. Nobody will read it.*

That is the horror register the whole game is written in — **the machinery
outlived the decision**, and being heard is not the same as being answered.

**R2 — does band 6 go too far?** It is the only line in the pass that tells the
player something about the listener. The safer version stops after *"a file
that was closed a long time ago"* and leaves the last three sentences out.

---

## B. Directive 9 itself — six pages, passed hand to hand

Foreign beacons already exist (§84), already wear RIVAL violet, and already
refuse the recovery hold with copy that states its own terms. They gain a
**second verb**: a short read that costs nothing and pays nothing.

**Which page a beacon carries is a pure function of its cell key** — the rival's
own covenant, zero bytes of save. The Authority's records persist; the refusers
leave nothing behind. That is the architecture agreeing with the fiction, and it
costs less than the alternative.

Plate sender lines read `DIRECTIVE 9 — PAGE n OF 6 · PASSED HAND TO HAND`.

**1.**
> *The frontier beyond the bearing terminus is reclassified UNSOUNDABLE. Survey
> operations in the reclassified volume are suspended indefinitely.*
> — handed to me at a fuel stop by somebody who would not give a name.

**2.**
> *No return filed from the reclassified volume shall be logged, corroborated,
> or entered against a commission.*
> — READ IT AGAIN. NOT REFUSED. NOT LOGGED. WE DID NOT FAIL TO COME BACK. WE
> CAME BACK AND IT DID NOT COUNT.

**3.**
> *Vessels remaining in the reclassified volume at the effective date are
> removed from the active register.*
> — THEY DID NOT SEND ANYONE. THEY DID THE PAPERWORK.

**4.**
> *Automated instruments, relays and standing security assets within the
> reclassified volume are to remain in service. Recall is not authorized at this
> time.*
> — EVERYTHING STILL SHOOTING AT US OUT HERE IS STILL SHOOTING AT US BECAUSE
> NOBODY WROTE THE SECOND MEMO.

**5.** *(the one that matters)*
> *APPENDIX B — NOT CIRCULATED. Reclassification is recommended on the grounds
> that continued resurvey would oblige the authority to publish successive
> charts of the same volume which do not agree. The commercial and legal
> exposure of publishing a chart known to be provisional is assessed as severe.*
> — THERE IT IS. NOT A MONSTER. A LIABILITY ASSESSMENT.

**6.**
> *ATTACHED: crews known to have filed after the effective date.*
> — the list is nine names long and I have met two of them. The last line is a
> hull in a livery nobody logged, last seen outbound, still filing.

Page 5 is the spine of the whole reveal: **they did not kill the frontier to
hide something. They killed it to save the map.** A place that will not hold
still proves that charting is a claim rather than a fact, and every chart the
authority ever sold rests on the opposite. Page 6 is the rival, named without
being named.

**R3 — six pages or four?** Six means a player who finds three foreign beacons
has half an order and a real reason to want the rest. Four means most players
who engage at all will complete it. I lean six.

---

## C. The player's own file

One line on the Commission page — the authority's file on you, which is now the
page where the authority contradicts itself:

> **RETURNS LOGGED FROM THE RECLASSIFIED VOLUME: —**
> *This field has been unset since Resurvey 44. Your filings are counted above.*

Resurvey 44 is THE FIRST MERIDIAN's own fragment ("*RESURVEY 44 FILED.
DISPLACEMENT OF DATUM: 41 UNITS*"), so the date the returns stopped is the date
the datum was found to move. The two records agree without either explaining the
other.

The existing closing line stays **exactly** as it is, and gets much worse for
free:

> THE FILE IS CLOSED. THE REGISTRY CARRIES YOUR NAME.

**R4 — is the registry line always visible, or only after Directive 9?** I
recommend **always**: an empty field with a dash in it, on a page that explains
everything else, never mentioned by anything. A playtester asking "what is that
dash?" is the design working. The cost is a player who asks and gets no answer
for twenty hours — which is the same deal the silhouette design already makes.

---

## D. The ship

One bark, fired once ever, at the moment the fragment is read. The crew voice
already ends band 6 with *"WE ARE THE RECORD NOW"* — this answers it:

> **WE ARE STILL FILING. SOMEBODY SHOULD KNOW THAT WE ARE STILL FILING.**

And one captain's-log line, in the log's terse register (`THE LINE HELD`,
`REFUSED THE TOLL`):

> **READ DIRECTIVE 9 — THE RETURNS WERE REFUSED**

---

## What is deliberately not touched

- **Every GSA broadcast, bands 1–4.** The machines were not told. If a recording
  changes its words, this pass is wrong.
- **Band 4's silence.** *"Do not 'finish' this entry"* stands, and now has a
  second reason to: nothing was transmitting there before the order either.
- **The Commission's statement-of-record posture.** One field is added. It is
  not a tracker, it does not tell the player to do anything, and it never
  updates.
- **No faction to join, no side to take, no questline.** The revelation changes
  the reader, not the rules. A rebellion arc would make the horror into content.
- **No new save.** Everything here is derived from v23's `deep_logs`, or is a
  pure function of a cell key.
