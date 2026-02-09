# NPC Relationship System

## Overview

Every NPC in the world starts at relationship level 0 -- Hostile. They do not know you, they do not trust you, and they will not do anything for you. Trust is earned through repeated interaction: talking, giving gifts, completing favors, helping with work, and trading. Neglect an NPC for too long and the relationship will decay back toward a baseline. Building strong relationships unlocks meaningful gameplay benefits, from trade discounts to equipment borrowing to NPCs who actively help you on the farm.

---

## The 7-Tier Relationship System

Your relationship with each NPC is tracked as a value from 0 to 100. That value maps to one of seven tiers, each with its own color indicator in the UI and a distinct set of unlocked benefits.

| Tier | Range | UI Color | What You Get |
|------|-------|----------|-------------|
| Hostile | 0 -- 9 | Red | Nothing. NPC will not offer favors, accept gifts, or provide any benefits. |
| Unfriendly | 10 -- 24 | Light Red | Basic interaction only. You can talk, but favors and gifts are still locked. |
| Neutral | 25 -- 39 | Orange | Can ask for favors. Can give gifts (at 30+). 5% trade discount. Small chance (5%) NPC will help. |
| Acquaintance | 40 -- 59 | Yellow | Can borrow equipment. 10% trade discount. 15% chance NPC will help. Higher favor frequency. |
| Friend | 60 -- 74 | Green | NPC may offer help unprompted. 15% trade discount. 35% chance NPC will help. |
| Close Friend | 75 -- 89 | Bright Green | NPC may give you gifts. 18% trade discount. 55% chance NPC will help. |
| Best Friend | 90 -- 100 | Blue | Full benefits. 20% trade discount. 75% chance NPC will help. Shared resources. NPC gives gifts more often. |

The color of the NPC's relationship text in the dialog changes as you progress through these tiers, giving you a visual indicator of where you stand at a glance.

---

## How to Gain Relationship

There are six ways to increase your relationship with an NPC:

| Action | Base Gain | Notes |
|--------|-----------|-------|
| **Talk** | +1 | Walk up and have a conversation. Only the first talk per day counts. |
| **Give Gift** | +5 | Costs $500. Requires Neutral (30+). Up to 3 gifts per day. Actual gain varies with personality and tier. |
| **Complete a Favor** | +15 | Finish a task the NPC asked you to do. Permanent gain. |
| **Help with Work** | +8 | Assist an NPC with their current job on the farm. |
| **Trade** | +3 | Complete any trade with the NPC. |
| **Emergency Help** | +25 | Help an NPC in an urgent situation. The largest single gain available. |

All positive gains can be amplified or reduced by the NPC's current mood (see Mood System below) and by any active grudges (see Grudge System below).

---

## Daily Limits

Not everything can be repeated endlessly in a single day:

- **Talking:** 1 conversation per NPC per day awards relationship points. You can still talk after the first time, but you will not gain any additional relationship.
- **Gifts:** Up to 3 gifts per NPC per day. After the third gift, the NPC will politely decline, saying they have received enough for today.

These limits reset at the start of each new in-game day.

---

## Relationship Decay

If you stop interacting with an NPC, the relationship will slowly erode:

- **Grace period:** 2 in-game days of no interaction before decay begins.
- **Decay rate:** -0.5 per in-game day (applied gradually).
- **Decay floor:** Relationship will never decay below 25 (Neutral). Once you have established a basic rapport, it does not vanish entirely from neglect -- but it will not stay high without effort.
- **Decay warning:** When you open a dialog with an NPC you have not spoken to in over 1.5 days, the greeting will include a warning that your relationship may be dropping.

The takeaway: check in with your NPCs regularly. A quick daily conversation is enough to prevent decay entirely.

---

## Mood System

NPCs have temporary moods that modify how much relationship you gain or lose from interactions.

- **How moods work:** Each NPC has a mood value ranging from -1.0 (very unhappy) to +1.0 (very happy). This value translates to a modifier of up to +/- 50% on all relationship changes.
- **Positive interactions** nudge the mood upward. Negative interactions push it down -- and negative events affect mood more strongly than positive ones.
- **Mood duration:** Temporary moods expire after about 2 in-game hours.
- **Base mood from relationship:** NPCs at Friend tier (60+) have a naturally positive mood toward you. NPCs at Hostile tier (0-9) carry a slight negative mood.
- **Visual indicator:** In the dialog, the NPC's personality text shows a mood symbol: `[+]` for happy, `[!]` for stressed, `[~]` for tired, or nothing for neutral mood. The text color also shifts (green for happy, orange for stressed, blue for tired).

A happy NPC will reward your positive actions more generously. An unhappy NPC will be harder to win over -- plan your interactions accordingly.

---

## Grudge System

NPCs remember when you wrong them, and those memories linger longer than a bad mood.

- **How grudges form:** Any negative relationship change (failed favor, abandoned favor, argument, ignored request) adds to a grudge. Each slight increases the grudge severity counter.
- **Grudge severity:** Ranges from 0 to 5 (maximum). Higher severity means the NPC is more resentful.
- **Effect on gains:** A grudge reduces the effectiveness of all positive relationship gains. At maximum severity (5), positive gains are cut by up to 50%. This stacks with the mood modifier.
- **Healing grudges:** Every positive interaction slowly reduces grudge severity by 0.1. Once severity drops to 0, the grudge is fully forgiven and removed.
- **Practical impact:** If you fail a favor or get into a disagreement, it will take sustained positive effort over multiple interactions to fully recover. The grudge does not block gains entirely -- it just makes the climb back harder.

---

## NPC-to-NPC Relationships

NPCs do not exist in isolation. They form relationships with each other based on personality compatibility.

- **Starting point:** All NPC-NPC relationships start at 50 (neutral).
- **Interactions:** When NPCs socialize, work together, or gather in the same area, their relationship changes. Working together gives the largest boost (+2 base), gathering gives +1.5, and casual socializing gives +1.
- **Personality compatibility:** Some personality pairings naturally get along better. The compatibility matrix:
  - **Strong positive:** Social + Social, Generous + Generous, Generous + Hardworking
  - **Mild positive:** Lazy + Lazy, Social + Generous, Hardworking + Hardworking
  - **Neutral:** Lazy + Grumpy, Hardworking + Grumpy
  - **Mild negative:** Grumpy + Generous, Grumpy + Grumpy
  - **Strong negative:** Hardworking + Lazy, Social + Grumpy
- **Decay:** NPC-NPC relationships that go without interaction for 3+ days slowly drift back toward 50 (neutral). Strong friendships fade, but so do rivalries.
- **Social grouping:** NPCs who like each other are more likely to spend time together, reinforcing their bond. NPCs who clash will naturally avoid each other.

---

## NPC-Initiated Gifts

Once you reach Close Friend (75+) with an NPC, they may start giving you gifts on their own.

- **Close Friends (75-89):** 5% chance per day that the NPC will bring you a small gift.
- **Best Friends (90-100):** 15% chance per day.
- **Personality matters:** Generous NPCs are twice as likely to give gifts. Grumpy NPCs almost never do (chance reduced to 20% of normal).
- **What you get:** A small relationship boost of +2 to +5 points, plus a friendly message from the NPC (e.g., "I brought you something from the farm. Hope you like it!").
- **No action required:** These gifts happen passively at the start of each in-game day. You will see a floating text notification near the NPC when it happens.

---

## Personality Modifiers

Each NPC has a personality trait that affects how they respond to your actions.

**Gift appreciation** -- how much an NPC values gifts you give them:

| Personality | Modifier | Effect |
|-------------|----------|--------|
| Generous | x1.2 | Appreciates gifts more than average. |
| Greedy | x1.5 | Really values expensive gifts. |
| Stingy | x0.8 | Somewhat less impressed by gifts. |
| Grumpy | x0.7 | Hard to please. Gifts have reduced impact. |
| Others | x1.0 | Standard appreciation. |

**Favor willingness** -- how likely an NPC is to agree when you ask for a favor:

| Personality | Modifier | Effect |
|-------------|----------|--------|
| Generous | x0.8 | Less likely to ask (prefers giving over taking). |
| Greedy | x1.5 | Very willing to assign favors (expects something in return). |
| Friendly | x1.2 | Happy to work with you. |
| Grumpy | x0.7 | Reluctant to engage. |

Favor willingness is also affected by time of day: NPCs are 30% more likely to offer favors during working hours (8:00-18:00) and 50% less likely outside those hours.

**Gift effectiveness by tier** -- your current relationship level also scales how impactful gifts are:

| Tier | Gift Effectiveness |
|------|-------------------|
| Hostile | 30% -- gifts barely register. |
| Unfriendly | 50% -- some acknowledgment. |
| Neutral | 70% -- reasonable impact. |
| Acquaintance | 80% -- gifts are well-received. |
| Friend | 90% -- strong appreciation. |
| Close Friend | 100% -- full value. |
| Best Friend | 120% -- gifts mean even more at this level. |

---

## Gift System

The primary gift mechanic is a $500 money gift, available through the dialog interface.

- **How to give:** Open the NPC dialog and click "Give gift ($500)".
- **Requirement:** You must be at Neutral relationship (30+) before the gift button unlocks.
- **Cost:** $500 is deducted from your account.
- **Base relationship gain:** +5, but actual gain depends on the NPC's personality modifier, your current tier's gift effectiveness, and the NPC's mood.
- **Daily limit:** 3 gifts per NPC per day. After the third, the NPC will decline.
- **NPC response:** Each personality type has a unique thank-you message. A grumpy NPC will mutter a reluctant thanks; a social NPC will promise to tell everyone how generous you are.

**Example calculation:** You give $500 to a Generous NPC at Acquaintance tier (gift effectiveness 80%) while they are in a good mood (+25% modifier). Base gain of 5 x 1.2 (generous) x 0.8 (acquaintance effectiveness) = 4.8, rounded to 4, then boosted by mood to 5.

---

## Quick Tips

- Talk to every NPC once a day. It costs nothing and prevents decay.
- Save your gifts for NPCs close to a tier threshold -- the unlock benefits are worth the investment.
- Avoid failing favors. The relationship loss (-10) is painful, and the grudge that forms makes recovery slower.
- Emergency help events are rare but extremely valuable at +25 relationship. Always prioritize them.
- Personality matters. A grumpy NPC takes more effort to befriend but offers the same benefits once you get there.
- Watch the mood indicator in the dialog. Giving a gift to a happy NPC gets you more value than giving to an upset one.
- NPC-NPC friendships develop on their own. Compatible neighbors will naturally form bonds without your involvement.
