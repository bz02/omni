import Foundation

extension ReflectionLibrary {
    /// Authored daily content, selected by the Gregorian date at the supplied timezone.
    /// The existing five-element color collection remains a creative styling lens.
    static func focusedRitual(for date: Date, focus: LifeFocus, calendar: Calendar = .current) -> DailyRitual {
        var localGregorian = Calendar(identifier: .gregorian)
        localGregorian.timeZone = calendar.timeZone
        let localDay = localGregorian.dateComponents([.year, .month, .day], from: date)
        var utcGregorian = Calendar(identifier: .gregorian)
        utcGregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = utcGregorian.date(from: localDay) ?? date
        let dayNumber = Int(floor(day.timeIntervalSince1970 / 86400))
        let collection: [FocusedRitualCopy]
        switch focus {
        case .myself: collection = FocusedRitualCopy.myself
        case .dating: collection = FocusedRitualCopy.dating
        case .relationship: collection = FocusedRitualCopy.relationship
        }
        let copy = collection[((dayNumber % collection.count) + collection.count) % collection.count]
        var result = ritual(for: date, calendar: calendar)
        result.eyebrow = copy.eyebrow
        result.title = copy.title
        result.reassurance = copy.reassurance
        result.question = copy.question
        result.action = copy.action
        return result
    }
}

private struct FocusedRitualCopy {
    let eyebrow: String
    let title: String
    let reassurance: String
    let question: String
    let action: String

    static let myself: [Self] = [
        .init(eyebrow: "ONE SMALL THING", title: "Make room\nfor one thing.",
              reassurance: "A busy day can still have a small corner that belongs to you.",
              question: "What would you like that corner to hold?",
              action: "Take 30 seconds to write one small thing you want to make room for today."),
        .init(eyebrow: "YOUR OWN PACE", title: "Your pace\ncan be yours.",
              reassurance: "Your available time and energy deserve a place in today's plans.",
              question: "Which plan could become a little smaller?",
              action: "Spend 45 seconds turning one item on your list into a smaller, more realistic step."),
        .init(eyebrow: "RIGHT AROUND YOU", title: "Notice what's\nalready here.",
              reassurance: "Something ordinary in your surroundings might be worth a second look.",
              question: "What detail have you walked past today?",
              action: "Look around for 30 seconds and name one color, one shape, and one detail you like."),
        .init(eyebrow: "A LIGHTER LIST", title: "A little less\nto carry.",
              reassurance: "You can decide how much belongs on today's list.",
              question: "What could wait without causing a real problem?",
              action: "Spend 30 seconds choosing one nonessential task to move off today's list."),
        .init(eyebrow: "EVERYDAY COMFORT", title: "Let comfort\ncount.",
              reassurance: "A small adjustment can make your next moment more comfortable.",
              question: "What around you would you like to adjust?",
              action: "Take 30 seconds to adjust your seat, add a comfortable layer, or clear space for your feet."),
        .init(eyebrow: "NOTICE YOUR EFFORT", title: "Give yourself\ncredit.",
              reassurance: "The effort you put into an ordinary day is easy to overlook.",
              question: "What did you handle that deserves a little acknowledgment?",
              action: "Spend 45 seconds writing one thing you did today and the effort it took."),
        .init(eyebrow: "A CHOICE THAT FITS", title: "Make a\nsmall choice.",
              reassurance: "Your preferences can guide the little decisions, too.",
              question: "Where would you like to choose what you actually enjoy?",
              action: "Take 30 seconds to choose a song, a comfortable layer, or a small detail for your space."),
        .init(eyebrow: "PUT IT INTO WORDS", title: "Name what\nyou need.",
              reassurance: "You can give a need a name before deciding what to do about it.",
              question: "What would feel useful right now?",
              action: "Spend 45 seconds finishing this sentence in your own words: 'Right now, I could use…'"),
        .init(eyebrow: "A MOMENT TO KEEP", title: "Keep a moment\nfor you.",
              reassurance: "A tiny pleasant moment can be worth remembering just as it was.",
              question: "What moment would you like to keep from today?",
              action: "Take 30 seconds to write one small moment you enjoyed, including a detail you noticed."),
        .init(eyebrow: "A SMALL BEGINNING", title: "Start where\nyou are.",
              reassurance: "You can begin with the materials, time, and attention you have today.",
              question: "What is the smallest visible beginning?",
              action: "Spend 60 seconds opening the page, laying out one item, or writing the first line of something you want to begin."),
        .init(eyebrow: "THE ORDINARY COUNTS", title: "Let the day\nbe ordinary.",
              reassurance: "A day can hold something worthwhile without a big event.",
              question: "Which ordinary part of today feels worth keeping?",
              action: "Spend 30 seconds noting one everyday detail you would like to remember tomorrow."),
        .init(eyebrow: "A LITTLE KINDNESS", title: "A kind place\nto pause.",
              reassurance: "You can make room for how today feels without needing a perfect explanation.",
              question: "What would a kind sentence to yourself sound like?",
              action: "Take 45 seconds to write yourself one kind, believable sentence about the day you're having."),
        .init(eyebrow: "YOUR OWN WORDS", title: "Return to\nyour own voice.",
              reassurance: "Your words can be simple and still describe something that matters.",
              question: "What do you want to say plainly?",
              action: "Spend 45 seconds rewriting one 'I should' thought as an honest preference, need, or choice."),
        .init(eyebrow: "ROOM BETWEEN THINGS", title: "Leave a\nlittle space.",
              reassurance: "The next open minute can remain open for a moment.",
              question: "What do you notice when you let a minute be unplanned?",
              action: "Set a 60-second timer and let yourself sit, stand, or look around without adding a task.")
    ]

    static let dating: [Self] = [
        .init(eyebrow: "A REAL QUESTION", title: "Curiosity\nis enough.",
              reassurance: "A question you actually care about gives you somewhere honest to begin.",
              question: "What would you enjoy learning about someone new?",
              action: "Spend 45 seconds writing one question you would enjoy asking on a date."),
        .init(eyebrow: "YOUR REAL INTERESTS", title: "Bring your\nreal taste.",
              reassurance: "The books, places, and little things you enjoy belong in the conversation.",
              question: "What interest would you enjoy sharing?",
              action: "Take 30 seconds to name one thing you've enjoyed lately and what you liked about it."),
        .init(eyebrow: "A CLEAR PREFERENCE", title: "Let your yes\nbe clear.",
              reassurance: "You can take a moment to check whether a plan works for you.",
              question: "What would make the plan feel comfortable and workable?",
              action: "Spend 45 seconds writing your preferred place, time, or kind of plan before replying."),
        .init(eyebrow: "A DAY THAT'S YOURS", title: "Keep your\nown evening.",
              reassurance: "Your day can include things you value while a dating conversation unfolds.",
              question: "What would you enjoy having in your evening?",
              action: "Take 30 seconds to name one enjoyable plan for yourself that doesn't depend on a reply."),
        .init(eyebrow: "AFTER THE MOMENT", title: "Notice how\nyou felt.",
              reassurance: "Your experience of a conversation is worth giving a little attention.",
              question: "When did you feel comfortable being yourself?",
              action: "Spend 60 seconds noting one moment of ease and one question you still have after an interaction."),
        .init(eyebrow: "ROOM TO LEARN", title: "Make room\nfor a maybe.",
              reassurance: "You can leave a question open while you get to know someone at your own pace.",
              question: "What would you like more information about?",
              action: "Take 45 seconds to write one thing you know from experience and one thing you are still learning."),
        .init(eyebrow: "AN EASY BEGINNING", title: "Choose a\nsimple question.",
              reassurance: "An everyday topic can give both people room to join a conversation.",
              question: "What easy topic would you enjoy exploring?",
              action: "Spend 30 seconds choosing a question about a favorite local spot, recent interest, or enjoyable part of the week."),
        .init(eyebrow: "WHAT WORKS FOR YOU", title: "Your comfort\ngets a vote.",
              reassurance: "Your preferences about timing, location, and pace are part of making a plan together.",
              question: "What preference would help you feel more comfortable?",
              action: "Take 45 seconds to draft one specific preference you could share about a possible date."),
        .init(eyebrow: "KEEP YOUR ANCHORS", title: "Keep one\npromise to you.",
              reassurance: "The parts of your life you care about can keep their place as you meet someone new.",
              question: "What small commitment to yourself matters this week?",
              action: "Spend 30 seconds naming one personal plan you want to keep on your calendar."),
        .init(eyebrow: "SOUND LIKE YOURSELF", title: "A message\nin your voice.",
              reassurance: "A clear, ordinary message can express what you mean.",
              question: "How would you say this out loud?",
              action: "Take 60 seconds to read an unsent draft and simplify one sentence so it sounds like you."),
        .init(eyebrow: "A SMALLER NEXT STEP", title: "Take the\npressure down.",
              reassurance: "You can decide on the next small step without deciding the whole future.",
              question: "What is the actual choice in front of you today?",
              action: "Spend 45 seconds writing the one decision you need to make now and leaving later decisions for later."),
        .init(eyebrow: "WHAT YOU VALUE", title: "Look for\nwhat matters.",
              reassurance: "Your values can help you notice which experiences feel like a good fit.",
              question: "Which quality matters to you in how you spend time together?",
              action: "Take 45 seconds to name one quality you value and a concrete example of what it would look like."),
        .init(eyebrow: "LET TIME BE TIME", title: "Let a pause\nbe a pause.",
              reassurance: "A gap between messages leaves room for uncertainty that you can acknowledge.",
              question: "What do you know, and what are you guessing?",
              action: "Spend 60 seconds writing one observed fact and one unanswered question about the conversation."),
        .init(eyebrow: "CHECK IN WITH YOU", title: "Stay open\nto yourself.",
              reassurance: "Your preferences may become clearer as you have new experiences.",
              question: "What have you learned about what you enjoy?",
              action: "Take 45 seconds to finish this sentence: 'Something I've learned about myself while dating is…'")
    ]

    static let relationship: [Self] = [
        .init(eyebrow: "THE EVERYDAY WORDS", title: "Say the\nsmall thing.",
              reassurance: "An ordinary thought can be worth sharing in a relationship.",
              question: "What small detail from your day would you like to share?",
              action: "Take 30 seconds to write one everyday detail you might enjoy telling your partner."),
        .init(eyebrow: "NOTICE SOMETHING REAL", title: "A little thanks,\nspecific.",
              reassurance: "A specific detail can make appreciation easier to put into words.",
              question: "What did you appreciate recently?",
              action: "Spend 45 seconds drafting one sentence that names something you appreciated and why it mattered to you."),
        .init(eyebrow: "ROOM FOR THEIR WORDS", title: "Make space\nto listen.",
              reassurance: "You can bring curiosity to a conversation while keeping your own perspective.",
              question: "What would you like to understand more clearly?",
              action: "Take 45 seconds to write one open question you could ask without guessing the answer."),
        .init(eyebrow: "ONE CLEAR ASK", title: "One request\nat a time.",
              reassurance: "A specific request gives a conversation something concrete to consider.",
              question: "What would you like to ask for?",
              action: "Spend 60 seconds drafting one request that names an action and a workable time, with room for their answer."),
        .init(eyebrow: "A SHARED MEMORY", title: "Remember\na good moment.",
              reassurance: "A shared moment can be meaningful in its small details.",
              question: "What recent moment together would you like to remember?",
              action: "Take 45 seconds to write one shared memory and a detail that made it pleasant for you."),
        .init(eyebrow: "A WORKABLE EVENING", title: "Let tonight\nbe simple.",
              reassurance: "The time and energy you each have today can help shape a realistic plan.",
              question: "What kind of evening would feel manageable for you?",
              action: "Spend 30 seconds naming one simple option you could suggest, including space to hear what works for them."),
        .init(eyebrow: "LET YOUR DAY BE KNOWN", title: "Share a\nlittle context.",
              reassurance: "A little context can help you describe where you're coming from today.",
              question: "What would you like your partner to know about your day?",
              action: "Take 45 seconds to finish: 'Today has felt ___, and right now I would appreciate ___.'"),
        .init(eyebrow: "SPACE FOR YOURSELF", title: "Keep your\nown interests.",
              reassurance: "Your individual interests can have a place alongside your shared life.",
              question: "What personal interest would you like to make room for?",
              action: "Spend 30 seconds noting one interest you want time for and when you could make a little space."),
        .init(eyebrow: "YOUR PART TO CHOOSE", title: "Notice\nyour part.",
              reassurance: "You can reflect on a choice you made while leaving responsibility for others' choices with them.",
              question: "What would you like to do differently in a future conversation?",
              action: "Take 60 seconds to name one specific action of your own you could adjust next time."),
        .init(eyebrow: "THE PRACTICAL DETAILS", title: "Check\nthe calendar.",
              reassurance: "Practical details sometimes deserve their own small conversation.",
              question: "What upcoming plan needs a little clarity?",
              action: "Spend 45 seconds identifying one calendar detail to check together, such as a time, task, or travel plan."),
        .init(eyebrow: "BEGIN WITH WHAT YOU MEAN", title: "A gentler\nopening.",
              reassurance: "You can prepare words that describe your experience clearly.",
              question: "How could you begin with what you noticed and felt?",
              action: "Take 60 seconds to draft an opening with one observable event and your own feeling, leaving out guesses about motives."),
        .init(eyebrow: "LEAVE ROOM TO ASK", title: "Ask what\nwould help.",
              reassurance: "There can be more than one way to offer company or practical help.",
              question: "What could you ask instead of assuming what is wanted?",
              action: "Spend 30 seconds drafting a question that offers listening, practical help, or space as possibilities."),
        .init(eyebrow: "SOMETHING LIGHT", title: "Save room\nfor play.",
              reassurance: "A little shared enjoyment can be as ordinary as a song or a familiar joke.",
              question: "What small thing might you both enjoy?",
              action: "Take 45 seconds to think of one light invitation you could offer, with an easy option to decline."),
        .init(eyebrow: "COME BACK CLEARLY", title: "Return\nwith intention.",
              reassurance: "You can think about the timing and purpose of a conversation before reopening it.",
              question: "What would you hope to understand or express?",
              action: "Spend 60 seconds writing one purpose for a conversation and a possible time to ask whether you're both available.")
    ]
}
