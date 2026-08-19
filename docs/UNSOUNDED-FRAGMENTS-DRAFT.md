# THE UNSOUNDED answers — fragment drafts (Horizon 7 commit 4)

**Status: DRAFT FOR REVIEW. No code exists yet, deliberately.** The horizon
plan's own gate: "the three fragments want drafting and reading aloud before
any of the mesh work starts." This is that draft. Read it aloud. Veto freely —
prose is cheap before the meshes exist and expensive after.

---

## The answer, in one paragraph

The frontier was not killed. It was **written off**. The GSA's grand survey —
the instrument network whose relics the player has been claiming as colonies:
THE ORRERY (position), THE CLEPSYDRA (time), THE ASTROLABE (bearing) — found
that the deep would not hold still long enough to be charted: positions
drifted between re-surveys, clocks disagreed past the instrument span, and the
horizon receded as fast as it was measured. So the authority did the actuarial
thing. It declared the frontier unsoundable, forbade returns, and filed it as
dead. *"Places nobody has filed a return from"* — the game's founding sentence
— turns out to be literal: the returns were not lost, they were **refused**.
The derelicts are what stood where the recall never reached, and every hostile
thing the player has fought — the apex **engines**, the wardens posted on
instruments, the automated convoys — is the survey apparatus, still running,
never told.

Why this answer and not a monster: it recontextualises everything already in
the game without retconning any of it, it is discovered rather than fought
(§76's "these are places" rule at full volume), and it hands the player a
quiet, earned irony — they are out here doing the exact thing the GSA proved
impossible, and their chart *holds*.

## Shape (unchanged from the horizon plan)

One structure per Pyx, past 5,200u, `SignatureSite`'s one-class pattern with a
`kind` per system. Three fragments each, read in stages — each stage a hold
that pays one fragment plus `chart_unsounded`, progress persisted at **v23**.
Not a fight; the wardens guard colonies, not these. These are graves with
paperwork.

---

## PYX-01 — THE FIRST MERIDIAN (position datum)

The zero point the ORRERY network measured from. A survey monolith, dark,
with the GSA's oldest livery still legible.

1. "GSA DATUM STATION 0. IF YOU CAN READ THIS, YOUR POSITION IS DEFINED.
   EVERY CHART OF THE FRONTIER BEGINS AT THIS MARK."
2. "RESURVEY 44 FILED. DISPLACEMENT OF DATUM: 41 UNITS. A ZERO POINT THAT
   MOVES IS NOT AN ERROR IN THE CHART. IT IS AN ERROR IN THE IDEA OF ONE."
3. "FINAL ENTRY. THE COMMISSION ASKS WHERE THE FRONTIER IS. WE HAVE MEASURED
   CAREFULLY AND THE HONEST ANSWER IS: WHEN."

## PYX-02 — THE STILL GLASS (time datum)

The master clock the CLEPSYDRA network was disciplined against, hanging in a
frozen spill of its own coolant — the slag tides' ancestor.

1. "GSA CHRONOMETRY VAULT. TWO CLOCKS AGREE HERE OR NOWHERE. ALL FRONTIER
   TIME IS THIS TIME."
2. "THE DEEP RUNS SLOW. NOT THE CLOCKS — WE CHANGED THE CLOCKS. THE CONVOYS
   CAME BACK YOUNG, WITH MANIFESTS SIGNED BY SCHEDULES THAT HAD ALREADY
   EXPIRED. COMMERCE DID NOT SURVIVE THE ARITHMETIC."
3. "FINAL ENTRY. WE ARE ORDERED HOME BY A DEADLINE COMPUTED IN A TIME THIS
   VAULT NO LONGER KEEPS. WE HAVE DECIDED TO BE LATE."

## PYX-03 — THE LAST RETURN (bearing datum)

The ASTROLABE network's outermost pylon — and moored to it, the evacuation
tender that never left. The closest thing the game will have to a mass grave,
and the fragment set states the decision plainly.

1. "GSA BEARING TERMINUS. ALL COURSES HOME ARE MEASURED FROM THIS PYLON.
   OUTBOUND ENDS HERE. EVERYTHING PAST THIS MARK IS BEARING ONLY."
2. "DIRECTIVE 9 RECEIVED. THE FRONTIER IS RECLASSIFIED UNSOUNDABLE. NO
   FURTHER RETURNS WILL BE LOGGED. CREWS BEYOND THE TERMINUS ARE INSTRUCTED
   NOT TO FILE. THE SURVEY THANKS THEM FOR THEIR CONTRIBUTION."
3. "FINAL ENTRY. THE ENGINES WERE NOT RECALLED. THE WARDENS WERE NOT STOOD
   DOWN. SOMEBODY DECIDED THE MACHINES DID NOT NEED TO KNOW. IF YOU ARE
   READING THIS, YOU CAME OUT ANYWAY — CHECK YOUR CLOCK, TRUST YOUR OWN
   MARKS, AND FILE A RETURN FOR US."

That last line is the game handing the player their own mechanics back:
beacons, filed cells, the persistent chart. Their return IS the filing.

## The rival's wreck (deferred from commit 3, lands with these)

One authored site, band 5, their livery. A single log, no stages:

"SURVEY LOG, INDEPENDENT. THE AUTHORITY SAYS THIS PLACE CANNOT BE CHARTED.
I HAVE FOUR HUNDRED CELLS FILED THAT SAY OTHERWISE. IF SOMEBODY FINDS THIS —
THE CHART WAS TRUE. THE CHART WAS TRUE, THE FUEL WAS SHORT."

The rival's arithmetic (§84) never told the player who they were racing.
This does. And "four hundred cells" is `SURVEY_CELL_CAP` — the wreck's log
and the player's own store cap are the same number, deliberately.

## Review questions

1. **Tone check**: the three "FINAL ENTRY" beats are the emotional spine. Too
   bleak? The relief valve is fragment 3-3's direct address, which turns the
   grave into a handoff.
2. **"WHEN" (1-3)**: the pivot line of the whole arc. If it reads as cryptic
   rather than chilling, the replacement is: "THE FRONTIER IS NOT A PLACE THE
   CHART CAN HOLD. IT IS A DATE."
3. **The physics**: "the deep runs slow" commits the fiction to mild time
   dilation. It explains the drift, the wrong clocks, and why depth is the
   axis of everything — but it is a commitment. Comfortable?
4. Structure names: THE FIRST MERIDIAN / THE STILL GLASS / THE LAST RETURN.
