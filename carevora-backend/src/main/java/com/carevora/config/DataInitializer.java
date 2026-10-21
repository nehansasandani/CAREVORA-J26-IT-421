package com.carevora.config;

import com.carevora.entity.*;
import com.carevora.enums.*;
import com.carevora.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;

@Component
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final ResidentRepository residentRepository;
    private final CaregiverRepository caregiverRepository;
    private final ElderHomeRepository elderHomeRepository;
    private final AssessmentRepository assessmentRepository;
    private final ContributingFactorRepository contributingFactorRepository;
    private final RecommendationRepository recommendationRepository;
    private final AlertRepository alertRepository;
    private final CognitiveAssessmentRepository cognitiveAssessmentRepository;
    private final PasswordEncoder passwordEncoder;

    public DataInitializer(
            UserRepository userRepository,
            ResidentRepository residentRepository,
            CaregiverRepository caregiverRepository,
            ElderHomeRepository elderHomeRepository,
            AssessmentRepository assessmentRepository,
            ContributingFactorRepository contributingFactorRepository,
            RecommendationRepository recommendationRepository,
            AlertRepository alertRepository,
            CognitiveAssessmentRepository cognitiveAssessmentRepository,
            PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.residentRepository = residentRepository;
        this.caregiverRepository = caregiverRepository;
        this.elderHomeRepository = elderHomeRepository;
        this.assessmentRepository = assessmentRepository;
        this.contributingFactorRepository = contributingFactorRepository;
        this.recommendationRepository = recommendationRepository;
        this.alertRepository = alertRepository;
        this.cognitiveAssessmentRepository = cognitiveAssessmentRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(String... args) {
        if (userRepository.count() > 0) {
            userRepository.findByEmail("sarah.jenkins@carevora.com").ifPresent(u -> {
                if (u.getAvatarUrl() == null) {
                    u.setAvatarUrl("assets/images/landing/testimonial_1.jpg");
                    userRepository.save(u);
                }
            });
            userRepository.findByEmail("arthur.p@carevora.com").ifPresent(u -> {
                if (u.getAvatarUrl() == null) {
                    u.setAvatarUrl("assets/images/landing/testimonial_2.jpg");
                    userRepository.save(u);
                }
            });
            userRepository.findByEmail("margaret.chen@carevora.com").ifPresent(u -> {
                if (u.getAvatarUrl() == null) {
                    u.setAvatarUrl("assets/images/landing/testimonial_3.jpg");
                    userRepository.save(u);
                }
            });
            userRepository.findByEmail("eleanor.vance@carevora.com").ifPresent(u -> {
                if (u.getAvatarUrl() == null) {
                    u.setAvatarUrl("assets/images/landing/caregivers_team.jpg");
                    userRepository.save(u);
                }
            });
            userRepository.findByEmail("david.silva@carevora.com").ifPresent(u -> {
                if (u.getAvatarUrl() == null) {
                    u.setAvatarUrl("assets/images/landing/testimonial_2.jpg");
                    userRepository.save(u);
                }
            });
            userRepository.findByEmail("dr.reed@carevora.com").ifPresent(u -> {
                if (u.getAvatarUrl() == null) {
                    u.setAvatarUrl("assets/images/landing/hero_caregiver_hug.jpg");
                    userRepository.save(u);
                }
            });
            return;
        }

        // ==========================================
        // 1. Seed Elder Homes (Facilities)
        // ==========================================
        ElderHome sereneValley = ElderHome.builder()
                .name("Serene Valley Senior Living")
                .facilityCode("SV-101")
                .address("12 Orchards Way, Colombo 07")
                .contactEmail("contact@serenevalley.com")
                .contactPhone("+94 11 234 5678")
                .active(true)
                .build();
        elderHomeRepository.save(sereneValley);

        ElderHome goldenSunset = ElderHome.builder()
                .name("Golden Sunset Eldercare")
                .facilityCode("GS-202")
                .address("45 Palm Grove, Kandy")
                .contactEmail("info@goldensunset.org")
                .contactPhone("+94 81 223 4455")
                .active(true)
                .build();
        elderHomeRepository.save(goldenSunset);

        // ==========================================
        // 2. Seed Doctor (Clinical Specialist - Oversees all elder homes)
        // ==========================================
        User doctorUser = User.builder()
                .email("dr.reed@carevora.com")
                .passwordHash(passwordEncoder.encode("doctor123"))
                .firstName("Samantha")
                .lastName("Reed")
                .role(UserRole.DOCTOR)
                .active(true)
                .build();
        userRepository.save(doctorUser);

        // ==========================================
        // 3. Seed Caregiver 1 (Serene Valley)
        // ==========================================
        User caregiver1User = User.builder()
                .email("eleanor.vance@carevora.com")
                .passwordHash(passwordEncoder.encode("carevora_admin"))
                .firstName("Eleanor")
                .lastName("Vance")
                .role(UserRole.CAREGIVER)
                .active(true)
                .build();
        userRepository.save(caregiver1User);

        Caregiver caregiver1 = Caregiver.builder()
                .user(caregiver1User)
                .elderHome(sereneValley)
                .staffCode("CG-101")
                .title("Lead Care Coordinator")
                .department("Senior Behavioral Health")
                .build();
        caregiverRepository.save(caregiver1);

        // ==========================================
        // 4. Seed Caregiver 2 (Golden Sunset)
        // ==========================================
        User caregiver2User = User.builder()
                .email("david.silva@carevora.com")
                .passwordHash(passwordEncoder.encode("carevora123"))
                .firstName("David")
                .lastName("Silva")
                .role(UserRole.CAREGIVER)
                .active(true)
                .build();
        userRepository.save(caregiver2User);

        Caregiver caregiver2 = Caregiver.builder()
                .user(caregiver2User)
                .elderHome(goldenSunset)
                .staffCode("CG-202")
                .title("Senior Care Specialist")
                .department("Active Living Support")
                .build();
        caregiverRepository.save(caregiver2);

        // ==========================================
        // 5. Seed Elders in Serene Valley (Home 1)
        // ==========================================
        // Resident 1: Sarah Jenkins (Serene Valley)
        User sarahUser = User.builder()
                .email("sarah.jenkins@carevora.com")
                .passwordHash(passwordEncoder.encode("carevora123"))
                .firstName("Sarah")
                .lastName("Jenkins")
                .role(UserRole.ELDER)
                .active(true)
                .build();
        userRepository.save(sarahUser);

        Resident sarah = Resident.builder()
                .user(sarahUser)
                .elderHome(sereneValley)
                .roomNumber("Suite 204")
                .age(78)
                .educationYears(12)
                .emergencyContact("+94 77 123 4567")
                .currentStatus(WellnessStatus.LOOKING_GOOD)
                .riskLevel(RiskLevel.LOW)
                .trajectory(TrajectoryStatus.IMPROVING)
                .emotionalScore(88.0)
                .socialScore(82.0)
                .cognitiveScore(85.0)
                .lastAssessmentDate(LocalDateTime.now().minusHours(2))
                .build();
        residentRepository.save(sarah);

        // Resident 2: Arthur Pendelton (Serene Valley)
        User arthurUser = User.builder()
                .email("arthur.p@carevora.com")
                .passwordHash(passwordEncoder.encode("carevora123"))
                .firstName("Arthur")
                .lastName("Pendelton")
                .role(UserRole.ELDER)
                .active(true)
                .build();
        userRepository.save(arthurUser);

        Resident arthur = Resident.builder()
                .user(arthurUser)
                .elderHome(sereneValley)
                .roomNumber("Suite 112")
                .age(82)
                .educationYears(10)
                .emergencyContact("+94 71 987 6543")
                .currentStatus(WellnessStatus.NEEDS_ATTENTION)
                .riskLevel(RiskLevel.MODERATE)
                .trajectory(TrajectoryStatus.INCREASING_RISK)
                .emotionalScore(54.0)
                .socialScore(48.0)
                .cognitiveScore(62.0)
                .lastAssessmentDate(LocalDateTime.now().minusHours(5))
                .build();
        residentRepository.save(arthur);

        // ==========================================
        // 6. Seed Elders in Golden Sunset (Home 2)
        // ==========================================
        // Resident 3: Margaret Chen (Golden Sunset)
        User margaretUser = User.builder()
                .email("margaret.c@carevora.com")
                .passwordHash(passwordEncoder.encode("carevora123"))
                .firstName("Margaret")
                .lastName("Chen")
                .role(UserRole.ELDER)
                .active(true)
                .build();
        userRepository.save(margaretUser);

        Resident margaret = Resident.builder()
                .user(margaretUser)
                .elderHome(goldenSunset)
                .roomNumber("Suite 305")
                .age(75)
                .educationYears(14)
                .emergencyContact("+94 76 555 4321")
                .currentStatus(WellnessStatus.STABLE)
                .riskLevel(RiskLevel.LOW)
                .trajectory(TrajectoryStatus.STABLE)
                .emotionalScore(76.0)
                .socialScore(78.0)
                .cognitiveScore(80.0)
                .lastAssessmentDate(LocalDateTime.now().minusHours(8))
                .build();
        residentRepository.save(margaret);

        // Resident 4: Robert Hastings (Golden Sunset)
        User robertUser = User.builder()
                .email("robert.h@carevora.com")
                .passwordHash(passwordEncoder.encode("carevora123"))
                .firstName("Robert")
                .lastName("Hastings")
                .role(UserRole.ELDER)
                .active(true)
                .build();
        userRepository.save(robertUser);

        Resident robert = Resident.builder()
                .user(robertUser)
                .elderHome(goldenSunset)
                .roomNumber("Suite 108")
                .age(84)
                .educationYears(12)
                .emergencyContact("+94 70 333 2211")
                .currentStatus(WellnessStatus.CHECK_IN_NEEDED)
                .riskLevel(RiskLevel.HIGH)
                .trajectory(TrajectoryStatus.INCREASING_RISK)
                .emotionalScore(38.0)
                .socialScore(35.0)
                .cognitiveScore(48.0)
                .lastAssessmentDate(LocalDateTime.now().minusHours(1))
                .build();
        residentRepository.save(robert);

        // ==========================================
        // 7. Seed Sample Assessments & Factors
        // ==========================================
        Assessment sarahAssessment = Assessment.builder()
                .resident(sarah)
                .overallScore(86.0)
                .emotionalScore(88.0)
                .socialScore(84.0)
                .status(WellnessStatus.LOOKING_GOOD)
                .riskLevel(RiskLevel.LOW)
                .trajectory(TrajectoryStatus.IMPROVING)
                .encouragingMessage("You're feeling uplifted and well connected today!")
                .facialCheckIncluded(true)
                .voiceCheckIncluded(true)
                .build();
        assessmentRepository.save(sarahAssessment);

        // Seed Sample Cognitive Assessment for Sarah Jenkins
        cognitiveAssessmentRepository.save(CognitiveAssessment.builder()
                .resident(sarah)
                .memoryScore(85.0)
                .attentionScore(88.0)
                .orientationScore(90.0)
                .recallScore(80.0)
                .reasoningScore(82.0)
                .acrfScore(85.15)
                .assessedBy("Eleanor Vance")
                .build());

        contributingFactorRepository.saveAll(List.of(
                ContributingFactor.builder().assessment(sarahAssessment).resident(sarah).title("Morning Garden Walk").score(92.0).category("Social").description("Active outdoor engagement noted early morning").build(),
                ContributingFactor.builder().assessment(sarahAssessment).resident(sarah).title("Calm Vocal Tone").score(85.0).category("Voice").description("Speech rhythm exhibited relaxed cadence").build(),
                ContributingFactor.builder().assessment(sarahAssessment).resident(sarah).title("Positive Expression").score(88.0).category("Facial").description("Frequent smiles during community greeting").build()
        ));

        recommendationRepository.save(Recommendation.builder()
                .resident(sarah)
                .assessment(sarahAssessment)
                .title("Afternoon Tea Social")
                .reason("Keep up the warm social connection with fellow residents.")
                .priority("Low")
                .suggestedAction("Join community lounge at 3:30 PM")
                .iconKey("social")
                .build());

        // Seed Alerts
        alertRepository.saveAll(List.of(
                Alert.builder().resident(robert).title("Sudden Dip in Social Wellness").message("Robert has missed group activities for 2 consecutive days.").type(AlertType.WELLNESS_ALERT).priority(AlertPriority.HIGH).isRead(false).build(),
                Alert.builder().resident(arthur).title("Risk Trajectory Shift").message("RALPA trajectory shifted from Stable towards Increasing Risk.").type(AlertType.RISK_ALERT).priority(AlertPriority.MEDIUM).isRead(false).build(),
                Alert.builder().resident(sarah).title("Daily Assessment Completed").message("Sarah completed her morning emotional wellness check-in.").type(AlertType.ASSESSMENT_ALERT).priority(AlertPriority.LOW).isRead(true).build()
        ));
    }
}
