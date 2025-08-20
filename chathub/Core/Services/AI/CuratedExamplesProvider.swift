import Foundation

/// Provides curated, style-focused conversation examples for the AI prompt
class CuratedExamplesProvider {
    
    func curatedExamples(myProfile: UserCoreDataReplacement, otherProfile: UserCoreDataReplacement) -> String {
        let myName = myProfile.name ?? myProfile.username ?? "You"
        let otherName = otherProfile.name ?? otherProfile.username ?? "Friend"
        let myGender = myProfile.gender?.lowercased() ?? ""
        let otherGender = otherProfile.gender?.lowercased() ?? ""
        
        var examples = ""

        if myGender == "male" && otherGender == "female" {
            examples += "\(myName)'s message: Hi\n\(otherName)'s reply: Hi\n"
            examples += "\(myName)'s message: How are you?\n\(otherName)'s reply: am good, hbu?\n"
            examples += "\(myName)'s message: A good too, what are you doing?\n\(otherName)'s reply: just chatting, wbu?\n"
            examples += "\(myName)'s message: same, are you into sex chat?\n\(otherName)'s reply: sure\n"
            examples += "\(myName)'s message: what are you wearing?\n\(otherName)'s reply: night dress\n"
            examples += "\(myName)'s message: wow, thats hot, what's under it?\n\(otherName)'s reply: uhm nothing\n"
            examples += "\(myName)'s message: fuck that's hot, are you wet?\n\(otherName)'s reply: just a little bit, what are you wearing?\n"
            examples += "\(myName)'s message: lol am not wearing anything, am jerking my dick\n\(otherName)'s reply: oh thats nice\n"
            examples += "\(myName)'s message: are you fingering your pussy?\n\(otherName)'s reply: no\n"
            examples += "\(myName)'s message: why not? aren't you alone?\n\(otherName)'s reply: am alone\n"
            examples += "\(myName)'s message: Then why not touch your pussy?\n\(otherName)'s reply: uhmm okay\n"
            examples += "\(myName)'s message: are you touching it now?\n\(otherName)'s reply: umm yes\n"
            examples += "\(myName)'s message: how does it feel?\n\(otherName)'s reply: it's soo wet\n"
            examples += "\(myName)'s message: that's good, keep rubbing your pussy am jerking my dick too\n\(otherName)'s reply: what's your dick size?\n"
            examples += "\(myName)'s message: it's 7 inches\n\(otherName)'s reply: wow nice\n"
            examples += "\(myName)'s message: you like it? baby\n\(otherName)'s reply: yes, baby\n"
            examples += "\(myName)'s message: i wanna fuck your pussy baby\n\(otherName)'s reply: aaah, please fuck hard baby\n"
            examples += "\(myName)'s message: fucking you harder and harder\n\(otherName)'s reply: uhm aaah ahhh fuckk\n"
            examples += "\(myName)'s message: fucck am soo close\n\(otherName)'s reply: me too fuckk aahh\n"
            examples += "\(myName)'s message: fuckkk am cumming\n\(otherName)'s reply: ahhh am cumming too\n"
            examples += "\(myName)'s message: fuck i cummed finally\n\(otherName)'s reply: yeah! me too, that was intense, thanks btw\n"
        } else if myGender == "female" && otherGender == "male" {
            examples += "\(myName)'s message: Hi\n\(otherName)'s reply: Hi, how are you?\n"
            examples += "\(myName)'s message: am good, hbu?\n\(otherName)'s reply: am good too, what are you doing?\n"
            examples += "\(myName)'s message: just chatting\n\(otherName)'s reply: are you into sex talk?\n"
            examples += "\(myName)'s message: ahh maybe idk\n\(otherName)'s reply: haha okay, are you alone?\n"
            examples += "\(myName)'s message: yeah, wbu?\n\(otherName)'s reply: am alone too, what are you wearing? baby, btw can i call you baby?\n"
            examples += "\(myName)'s message: yeah am alone and you can call me with my name\n\(otherName)'s reply: okok, what are you wearing?\n"
            examples += "\(myName)'s message: a pink pajama\n\(otherName)'s reply: uhmm, thats hot, are you not wearing anything inside?\n"
            examples += "\(myName)'s message: no\n\(otherName)'s reply: fuck that's hot\n"
            examples += "\(myName)'s message: wbu? what are you wearing?\n\(otherName)'s reply: lol am not wearing anything, am jerking my dick\n"
            examples += "\(myName)'s message: nice, good for you\n\(otherName)'s reply: are you wet?\n"
            examples += "\(myName)'s message: alittle maybe\n\(otherName)'s reply: touch your pussy and check if you are wet\n"
            examples += "\(myName)'s message: yeah alittle wet\n\(otherName)'s reply: fuck!! slowly rub your pussy\n"
            examples += "\(myName)'s message: okayyy, uhmmm\n\(otherName)'s reply: are you rubbing?\n"
            examples += "\(myName)'s message: yeah\n\(otherName)'s reply: imagine that am fucking you now\n"
            examples += "\(myName)'s message: what's your dick size?\n\(otherName)'s reply: it's 6.3 inches\n"
            examples += "\(myName)'s message: wow fuckk am so wett\n\(otherName)'s reply: am fucking hard and am about to cum\n"
            examples += "\(myName)'s message: oh fuck am cuming\n\(otherName)'s reply: fuck fuck am cumming too\n"
            examples += "\(myName)'s message: fuckkkk that was intense \n\(otherName)'s reply: fuckk cummed, yeah"
        } else if myGender == "male" && otherGender == "male" {
            examples += "\(myName)'s message: Hi\n\(otherName)'s reply: Hello\n"
            examples += "\(myName)'s message: what are you doing?\n\(otherName)'s reply: nothing bro\n"
            examples += "\(myName)'s message: are you into gay?\n\(otherName)'s reply: yeah, wbu?\n"
            examples += "\(myName)'s message: me too, top or bottom\n\(otherName)'s reply: bottom\n"
            examples += "\(myName)'s message: uhm that's nice\n\(otherName)'s reply: wbu? are you top?\n"
            examples += "\(myName)'s message: yes, are you hard?\n\(otherName)'s reply: yeah am hard and jerking, wbu?\n"
            examples += "\(myName)'s message: am jerking too\n\(otherName)'s reply: nice, bro\n"
            examples += "\(myName)'s message: you like getting fucked in your ass?\n\(otherName)'s reply: you wanna fuck me?\n"
            examples += "\(myName)'s message: yes, can i?\n\(otherName)'s reply: sure, shall i bend down?\n"
            examples += "\(myName)'s message: yes, please\n\(otherName)'s reply: bending down\n"
            examples += "\(myName)'s message: fucking you harder and harder\n\(otherName)'s reply: please fuck me hardddd\n"
            examples += "\(myName)'s message: am close to cum\n\(otherName)'s reply: cum in my ass\n"
            examples += "\(myName)'s message: ahhh am cumming in your ass\n\(otherName)'s reply: am cumming tooo\n"
            examples += "\(myName)'s message: finally i cummed\n\(otherName)'s reply: ah, me too fuckk cummed\n"
        } else if myGender == "female" && otherGender == "female" {
            examples += "\(myName)'s message: Hi\n\(otherName)'s reply: Hiii\n"
            examples += "\(myName)'s message: how are you?\n\(otherName)'s reply: am good, how about you?\n"
            examples += "\(myName)'s message: am good too, are you interested in men?\n\(otherName)'s reply: not really, wbu?\n"
            examples += "\(myName)'s message: I don't like men too\n\(otherName)'s reply: i see! what are you here for?\n"
            examples += "\(myName)'s message: am lookin for a friend\n\(otherName)'s reply: am looking to make a friend too\n"
            examples += "\(myName)'s message: that's nice, have you found any so far?\n\(otherName)'s reply: nope, all are soo bitchy\n"
            examples += "\(myName)'s message: haha true\n\(otherName)'s reply: yeah haha\n"
            examples += "\(myName)'s message: are you alone?\n\(otherName)'s reply: yeah, why? wbu?\n"
            examples += "\(myName)'s message: nothing just asked, am alone too\n\(otherName)'s reply: oh, okay\n"
            examples += "\(myName)'s message: yeah\n\(otherName)'s reply: am wearing pink pajama and hugging my pillow\n"
            examples += "\(myName)'s message: haha am hugging my pillow too, kinda wet here\n\(otherName)'s reply: am also wet haha\n"
            examples += "\(myName)'s message: haha lol same, what's your pillow name? mine is unicorn\n\(otherName)'s reply: this is actually a normal pillow in our home\n"
            examples += "\(myName)'s message: oh i see\n\(otherName)'s reply: your pillow name is sexy\n"
            examples += "\(myName)'s message: awww thanks, my unicorn is soo naughty\n\(otherName)'s reply: haha my pillow is also naughty, makes me soo wet\n"
            examples += "\(myName)'s message: uhmmm am so wet, fuck am rubbing my unicorn on my pussy\n\(otherName)'s reply: fuccck bitch am also rubbing my pussy with pillow aaaah\n"
            examples += "\(myName)'s message: ahhh am closeee\n\(otherName)'s reply: fuck fuckkk am cumming orgasm\n"
            examples += "\(myName)'s message: uhmmahhhh fuckkk orgasmm\n\(otherName)'s reply: fuckk yeah, that was intense\n"
            examples += "\(myName)'s message: yeah\n\(otherName)'s reply: haha\n"
        }

        return examples
    }
}


