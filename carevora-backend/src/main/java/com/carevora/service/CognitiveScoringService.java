package com.carevora.service;

import java.time.LocalDate;
import java.util.*;
import java.util.regex.Pattern;

/**
 * Question-specific deterministic automatic scoring engine for Carevora Cognitive Assessments.
 * Implements deterministic grading rules across the 10-question cognitive battery,
 * domain accuracy calculations, ACRF weighted score derivation, and response-time aggregation.
 */
public class CognitiveScoringService {

    public static final Map<String, Double> DOMAIN_WEIGHTS = Map.of(
            "memory", 0.25,
            "attention", 0.20,
            "orientation", 0.20,
            "recall", 0.20,
            "reasoning", 0.15
    );

    public static final Map<Integer, String> QUESTION_DOMAIN_MAP = Map.of(
            1, "orientation",
            2, "orientation",
            3, "memory",
            4, "memory",
            5, "attention",
            6, "attention",
            7, "recall",
            8, "recall",
            9, "reasoning",
            10, "reasoning"
    );

    public static final Map<String, List<Integer>> QUESTION_IDS_BY_DOMAIN = Map.of(
            "orientation", List.of(1, 2),
            "memory", List.of(3, 4),
            "attention", List.of(5, 6),
            "recall", List.of(7, 8),
            "reasoning", List.of(9, 10)
    );

    /**
     * Normalizes raw response string: lowercase, punctuation to spaces, collapses whitespace, trims.
     */
    public static String normalizeAnswer(String input) {
        if (input == null) return "";
        // Replace punctuation with spaces to avoid merging adjacent words
        String cleaned = input.toLowerCase().replaceAll("[.,/#!$%^&*;:{}=\\-_`~()?\"'’]", " ");
        return cleaned.replaceAll("\\s+", " ").trim();
    }

    /**
     * Scores a single question deterministically according to question-specific rubric.
     * Returns 1.0 (Correct), 0.5 (Partial, where rubric allows), 0.0 (Incorrect),
     * or null if the response is missing/blank.
     * Missing response is NEVER graded as 0.0.
     */
    public static Double scoreQuestion(int questionId, String rawAnswer, LocalDate referenceDate) {
        if (rawAnswer == null || rawAnswer.trim().isEmpty()) {
            return null;
        }

        String normalized = normalizeAnswer(rawAnswer);
        if (normalized.isEmpty()) {
            return null;
        }

        LocalDate ref = referenceDate != null ? referenceDate : LocalDate.now();

        switch (questionId) {
            case 1: {
                // Q1: What day is it today? (English, Sinhala Unicode & Singlish weekday names)
                String currentDayName = ref.getDayOfWeek().name().toLowerCase();
                Pattern p = Pattern.compile("\\b" + currentDayName + "\\b");
                if (p.matcher(normalized).find()) {
                    return 1.0;
                }
                Map<Integer, List<String>> sinhalaWeekdays = Map.of(
                        1, List.of("සඳුදා", "සදුදා", "සඳුද", "සදුද", "sanduda", "saduda", "handuda"),
                        2, List.of("අඟහරුවාදා", "අගහරුවාදා", "අඟහරුවාද", "අගහරුවාද", "අඟහරු", "අගහරු", "angaharuwada", "agaharuwada"),
                        3, List.of("බදාදා", "බදාද", "badada", "badaada", "badhada"),
                        4, List.of("බ්‍රහස්පතින්දා", "බ්රහස්පතින්දා", "බ්‍රහස්පතින්ද", "බ්රහස්පතින්ද", "බ්‍රහස්පති", "බ්රහස්පති", "brahaspathinda", "brahaspatinda", "brahaspathindha"),
                        5, List.of("සිකුරාදා", "සිකුරාද", "sikurada", "sikuraada"),
                        6, List.of("සෙනසුරාදා", "සෙනසුරාද", "senasurada", "senasuraada"),
                        7, List.of("ඉරිදා", "ඉරිද", "irida", "iridha", "iriida")
                );
                String rawClean = rawAnswer.replace("\u200d", "");
                List<String> variants = sinhalaWeekdays.getOrDefault(ref.getDayOfWeek().getValue(), List.of());
                for (String v : variants) {
                    if (rawAnswer.contains(v) || rawClean.contains(v.replace("\u200d", "")) || normalized.contains(v)) {
                        return 1.0;
                    }
                }
                return 0.0;
            }
            case 2: {
                // Q2: What year is this? (English, digits with Sinhala suffixes, Sinhala Unicode & Singlish)
                String currentYear = String.valueOf(ref.getYear());
                Pattern p = Pattern.compile("(?<!\\d)" + currentYear + "(?!\\d)");
                boolean matches = p.matcher(rawAnswer).find() ||
                        normalized.contains("twenty twenty six") ||
                        normalized.contains("twenty twenty-six") ||
                        rawAnswer.contains("දෙදහස් විසි හය") ||
                        rawAnswer.contains("දෙදහස් විසිහය") ||
                        rawAnswer.contains("දෙදාස් විසි හය") ||
                        rawAnswer.contains("දෙදාස් විසිහය") ||
                        rawAnswer.contains("විසි හය") ||
                        rawAnswer.contains("විසිහය") ||
                        normalized.contains("dedahas visi haya") ||
                        normalized.contains("dedahas wisi haya") ||
                        normalized.contains("dedaas visi haya") ||
                        normalized.contains("dedaas wisi haya") ||
                        normalized.contains("wisi haya") ||
                        normalized.contains("visi haya");
                return matches ? 1.0 : 0.0;
            }
            case 3:
            case 4:
            case 7: {
                // Q3: Repeat these words: Sun, Book, Tree (ඉර, පොත, ගස).
                // Q4: Say those three words once more.
                // Q7: What were the three words from earlier?
                Set<String> distinctTargets = new HashSet<>();
                if (Pattern.compile("\\b(sun|ira|hiru)\\b").matcher(normalized).find()
                        || rawAnswer.contains("ඉර") || rawAnswer.contains("හිරු") || rawAnswer.contains("සූර්ය")) {
                    distinctTargets.add("sun");
                }
                if (Pattern.compile("\\b(books?|potha|pota|poth)\\b").matcher(normalized).find()
                        || rawAnswer.contains("පොත") || rawAnswer.contains("පොත්") || rawAnswer.contains("පුස්තක")) {
                    distinctTargets.add("book");
                }
                if (Pattern.compile("\\b(trees?|gasa|gaha|gas)\\b").matcher(normalized).find()
                        || rawAnswer.contains("ගස") || rawAnswer.contains("ගහ") || rawAnswer.contains("ගස්")
                        || rawAnswer.contains("රුක") || rawAnswer.contains("වෘක්ෂ")) {
                    distinctTargets.add("tree");
                }

                int count = distinctTargets.size();
                if (count == 3) return 1.0;
                if (count >= 1) return 0.5; // Partial credit for 1-2 words
                return 0.0;
            }
            case 5: {
                // Q5: What is 2 plus 3? Accept 5, five, පහ, paha
                boolean isFive = Pattern.compile("(?<!\\d)5(?!\\d)").matcher(rawAnswer).find() ||
                        Pattern.compile("\\b(5|five|paha|pahai|pahayi|pahal)\\b").matcher(normalized).find() ||
                        rawAnswer.contains("පහ");
                return isFive ? 1.0 : 0.0;
            }
            case 6: {
                // Q6: Which is bigger: 3 or 8? Accept 8, eight, අට, ata
                boolean mentionsEight = Pattern.compile("(?<!\\d)8(?!\\d)").matcher(rawAnswer).find() ||
                        Pattern.compile("\\b(8|eight|ata|atai|atayi|atha)\\b").matcher(normalized).find() ||
                        rawAnswer.contains("අට");
                boolean saysThreeBigger = Pattern.compile("\\b(3|three|thuna)\\s+(is\\s+)?(bigger|lokui|visalai)\\b").matcher(normalized).find() ||
                        rawAnswer.contains("තුන ලොකු") || rawAnswer.contains("තුන විශාල") ||
                        rawAnswer.contains("3 ලොකු") || rawAnswer.contains("3 විශාල");
                return (mentionsEight && !saysThreeBigger) ? 1.0 : 0.0;
            }
            case 8: {
                // Q8: Did you hear the word Sun earlier? Accept unambiguous affirmative
                boolean isAffirmative = Pattern.compile("\\b(yes|yeah|yep|yup|i did|affirmative|certainly|sure|true|correct|heard|i heard|i heard sun|heard sun|heard it|i heard it|yes i did|ow|ou|owu|ahuna|asuna|asuwa|ahuwa|hari|ehemai|ehemayi)\\b").matcher(normalized).find() ||
                        rawAnswer.contains("ඔව්") || rawAnswer.contains("ඔවු") ||
                        rawAnswer.contains("ඇසුණා") || rawAnswer.contains("ඇසුනා") ||
                        rawAnswer.contains("ඇහුණා") || rawAnswer.contains("ඇහුනා") ||
                        rawAnswer.contains("තිබුණා") || rawAnswer.contains("තිබුනා") ||
                        rawAnswer.contains("කිව්වා") || rawAnswer.contains("හරි") ||
                        rawAnswer.contains("එහෙමයි");
                boolean isNegative = Pattern.compile("\\b(no|nope|not|never|did not|didn t|didnt|naha|naa|nae|nehe)\\b").matcher(normalized).find() ||
                        rawAnswer.contains("නැහැ") || rawAnswer.contains("නෑ") || rawAnswer.contains("නැත");
                return (isAffirmative && !isNegative) ? 1.0 : 0.0;
            }
            case 9: {
                // Q9: What do you use to tell the time?
                boolean hasValidDevice = Pattern.compile(
                        "\\b(clock|clocks|watch|watches|wristwatch|wristwatches|smartwatch|smartwatches|pocketwatch|stopwatch|timepiece|timepieces|chronometer|chronometers|sundial|sundials|hourglass|hourglasses|oralosuwa|oralosu|ath oralosuwa)\\b"
                ).matcher(normalized).find() ||
                        rawAnswer.contains("ඔරලෝසු") || rawAnswer.contains("අත් ඔරලෝසු") || rawAnswer.contains("බිත්ති ඔරලෝසු");

                boolean isNegated = Pattern.compile(
                        "\\b(no|not|never|neither|without)\\s+(a\\s+|an\\s+|the\\s+|my\\s+|any\\s+)?(clock|clocks|watch|watches|wristwatch|timepiece|sundial)\\b"
                ).matcher(normalized).find()
                || Pattern.compile(
                        "\\b(don t know|dont know|no idea|cannot tell|can t tell|cant tell|not sure|unsure|don t use|dont use|do not use|danne na|danne naha)\\b"
                ).matcher(normalized).find()
                || Pattern.compile(
                        "^(no|nope|not|never|nothing|none)\\b"
                ).matcher(normalized).find()
                || rawAnswer.contains("දන්නේ නෑ") || rawAnswer.contains("දන්නෙ නෑ");

                boolean isDisallowedIdiom = Pattern.compile(
                        "\\b(biological clock|body clock|around the clock|round the clock|against the clock|clock in|clock out|punch the clock|clean your clock)\\b"
                ).matcher(normalized).find();

                return (hasValidDevice && !isNegated && !isDisallowedIdiom) ? 1.0 : 0.0;
            }
            case 10: {
                // Q10: Are an apple and an orange both fruits?
                boolean isFruits = Pattern.compile("\\b(yes|both fruits|both are fruits|fruits|fruit|they are fruits|yes they are|affirmative|correct|ow|ou|owu|palathuru|palaturu|hari|ehemai|ehemayi)\\b").matcher(normalized).find() ||
                        rawAnswer.contains("ඔව්") || rawAnswer.contains("ඔවු") ||
                        rawAnswer.contains("පලතුරු") || rawAnswer.contains("පළතුරු") ||
                        rawAnswer.contains("හරි") || rawAnswer.contains("එහෙමයි") ||
                        rawAnswer.contains("සත්‍ය");
                boolean isNegative = Pattern.compile("\\b(no|nope|neither|vegetables?|naha|naa|nae|nehe|elawalu)\\b").matcher(normalized).find() ||
                        rawAnswer.contains("නැහැ") || rawAnswer.contains("නෑ") || rawAnswer.contains("නැත") ||
                        rawAnswer.contains("එළවළු") || rawAnswer.contains("එලවලු");
                return (isFruits && !isNegative) ? 1.0 : 0.0;
            }
            default:
                return 0.0;
        }
    }

    /**
     * Scores all questions in the 10-question battery.
     */
    public static Map<Integer, Double> scoreBattery(Map<Integer, String> responses, LocalDate referenceDate) {
        Map<Integer, Double> grades = new HashMap<>();
        for (int i = 1; i <= 10; i++) {
            String answer = responses != null ? responses.get(i) : null;
            Double score = scoreQuestion(i, answer, referenceDate);
            if (score != null) {
                grades.put(i, score);
            }
        }
        return grades;
    }

    /**
     * Checks if all 10 questions have valid non-blank responses.
     */
    public static boolean isAllQuestionsAnswered(Map<Integer, String> responses) {
        if (responses == null) return false;
        for (int i = 1; i <= 10; i++) {
            String val = responses.get(i);
            if (val == null || val.trim().isEmpty()) {
                return false;
            }
        }
        return true;
    }

    /**
     * Returns list of question IDs (1..10) that lack an answer.
     */
    public static List<Integer> getUnansweredQuestionIds(Map<Integer, String> responses) {
        List<Integer> unanswered = new ArrayList<>();
        for (int i = 1; i <= 10; i++) {
            String val = responses != null ? responses.get(i) : null;
            if (val == null || val.trim().isEmpty()) {
                unanswered.add(i);
            }
        }
        return unanswered;
    }

    /**
     * Calculates domain accuracies in [0.0, 1.0] range from question grades.
     */
    public static Map<String, Double> calculateDomainAccuracies(Map<Integer, Double> grades) {
        Map<String, Double> accuracies = new HashMap<>();
        for (Map.Entry<String, List<Integer>> entry : QUESTION_IDS_BY_DOMAIN.entrySet()) {
            String domain = entry.getKey();
            List<Integer> qIds = entry.getValue();
            double sum = 0.0;
            for (Integer qId : qIds) {
                Double g = grades != null ? grades.get(qId) : null;
                if (g != null && !Double.isNaN(g)) {
                    sum += g;
                }
            }
            double mean = sum / qIds.size();
            accuracies.put(domain, Math.round(mean * 10000.0) / 10000.0);
        }
        return accuracies;
    }

    /**
     * Calculates domain scores on [0.0, 100.0] scale from accuracies.
     */
    public static Map<String, Double> calculateDomainScores(Map<String, Double> accuracies) {
        Map<String, Double> scores = new HashMap<>();
        for (String domain : DOMAIN_WEIGHTS.keySet()) {
            Double acc = accuracies != null ? accuracies.getOrDefault(domain, 0.0) : 0.0;
            scores.put(domain, Math.round(acc * 100.0 * 100.0) / 100.0);
        }
        return scores;
    }

    /**
     * Calculates arithmetic ACRF score:
     * memory*0.25 + attention*0.20 + orientation*0.20 + recall*0.20 + reasoning*0.15
     */
    public static Double calculateAcrfScore(Map<String, Double> domainScores) {
        double total = 0.0;
        for (Map.Entry<String, Double> entry : DOMAIN_WEIGHTS.entrySet()) {
            String domain = entry.getKey();
            Double weight = entry.getValue();
            Double score = domainScores != null ? domainScores.getOrDefault(domain, 0.0) : 0.0;
            total += score * weight;
        }
        return Math.round(total * 100.0) / 100.0;
    }

    public static Double calculateAcrfScore(Double memory, Double attention, Double orientation, Double recall, Double reasoning) {
        double m = memory != null ? memory : 0.0;
        double a = attention != null ? attention : 0.0;
        double o = orientation != null ? orientation : 0.0;
        double rc = recall != null ? recall : 0.0;
        double rs = reasoning != null ? reasoning : 0.0;
        double total = (m * 0.25) + (a * 0.20) + (o * 0.20) + (rc * 0.20) + (rs * 0.15);
        return Math.round(total * 100.0) / 100.0;
    }

    /**
     * Aggregates question response times in seconds to domain response times.
     * Enforces minimum 0.5s.
     */
    public static Map<String, Double> aggregateDomainResponseTimes(Map<Integer, Double> questionTimes) {
        Map<String, Double> responseTimes = new HashMap<>();
        for (Map.Entry<String, List<Integer>> entry : QUESTION_IDS_BY_DOMAIN.entrySet()) {
            String domain = entry.getKey();
            List<Integer> qIds = entry.getValue();
            double totalTime = 0.0;
            int count = 0;
            for (Integer qId : qIds) {
                Double t = questionTimes != null ? questionTimes.get(qId) : null;
                if (t != null && !Double.isNaN(t) && t > 0.0) {
                    totalTime += t;
                    count++;
                }
            }
            double mean = count > 0 ? (totalTime / count) : 4.0;
            double clamped = Math.max(0.5, mean);
            responseTimes.put(domain, Math.round(clamped * 100.0) / 100.0);
        }
        return responseTimes;
    }
}
