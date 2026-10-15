package com.carevora.service;

import com.carevora.dto.ApiResponse;
import com.carevora.entity.Assessment;
import com.carevora.entity.ElderHome;
import com.carevora.entity.Resident;
import com.carevora.enums.RiskLevel;
import com.carevora.enums.TrajectoryStatus;
import com.carevora.enums.WellnessStatus;
import com.carevora.repository.AssessmentRepository;
import com.carevora.repository.ElderHomeRepository;
import com.carevora.repository.ResidentRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Transactional
class AiMlServiceIntegrationTest {

    @Autowired
    private AiMlService aiMlService;

    @Autowired
    private AssessmentRepository assessmentRepository;

    @Autowired
    private ResidentRepository residentRepository;

    @Autowired
    private ElderHomeRepository elderHomeRepository;

    @Autowired
    private com.carevora.repository.UserRepository userRepository;

    private Resident testResident;

    @BeforeEach
    void setUp() {
        ElderHome home = elderHomeRepository.findAll().stream().findFirst().orElse(null);
        if (home == null) {
            home = elderHomeRepository.save(ElderHome.builder()
                    .name("Test Elder Home")
                    .facilityCode("TEH-01")
                    .address("Colombo")
                    .active(true)
                    .build());
        }

        com.carevora.entity.User user = userRepository.save(com.carevora.entity.User.builder()
                .email("test.elder." + System.nanoTime() + "@carevora.com")
                .passwordHash("hashed_pwd")
                .firstName("Test")
                .lastName("Elder")
                .role(com.carevora.enums.UserRole.ELDER)
                .active(true)
                .build());

        testResident = residentRepository.save(Resident.builder()
                .user(user)
                .elderHome(home)
                .roomNumber("Room 999")
                .age(80)
                .currentStatus(WellnessStatus.LOOKING_GOOD)
                .riskLevel(RiskLevel.LOW)
                .trajectory(TrajectoryStatus.STABLE)
                .emotionalScore(80.0)
                .socialScore(80.0)
                .build());
    }

    @Test
    @DisplayName("Verify Chronological Ordering: Decreasing wellness produces ASC chronological history and increasing risk trend")
    void testChronologicalOrdering_DecreasingWellness() {
        LocalDateTime baseTime = LocalDateTime.now().minusDays(10);

        // Save assessments at distinct times with decreasing wellness
        // T1 (oldest): 90.0, T2 (middle): 75.0, T3 (newest): 55.0
        Assessment a1 = assessmentRepository.save(Assessment.builder()
                .resident(testResident)
                .overallScore(90.0)
                .emotionalScore(90.0)
                .socialScore(90.0)
                .createdAt(baseTime.plusDays(1))
                .status(WellnessStatus.LOOKING_GOOD)
                .riskLevel(RiskLevel.LOW)
                .trajectory(TrajectoryStatus.STABLE)
                .build());

        Assessment a2 = assessmentRepository.save(Assessment.builder()
                .resident(testResident)
                .overallScore(75.0)
                .emotionalScore(75.0)
                .socialScore(75.0)
                .createdAt(baseTime.plusDays(2))
                .status(WellnessStatus.STABLE)
                .riskLevel(RiskLevel.MODERATE)
                .trajectory(TrajectoryStatus.STABLE)
                .build());

        Assessment a3 = assessmentRepository.save(Assessment.builder()
                .resident(testResident)
                .overallScore(55.0)
                .emotionalScore(55.0)
                .socialScore(55.0)
                .createdAt(baseTime.plusDays(3))
                .status(WellnessStatus.NEEDS_ATTENTION)
                .riskLevel(RiskLevel.HIGH)
                .trajectory(TrajectoryStatus.INCREASING_RISK)
                .build());

        // 1. Raw repository query orders by createdAt DESC (newest first)
        List<Assessment> rawDesc = assessmentRepository.findByResidentIdOrderByCreatedAtDesc(testResident.getId());
        assertEquals(3, rawDesc.size());
        assertEquals(55.0, rawDesc.get(0).getOverallScore(), "First in DESC must be newest assessment (55.0)");
        assertEquals(75.0, rawDesc.get(1).getOverallScore(), "Second in DESC must be middle assessment (75.0)");
        assertEquals(90.0, rawDesc.get(2).getOverallScore(), "Third in DESC must be oldest assessment (90.0)");

        // 2. Verified chronological history scores extracted by AiMlService must be strictly chronological ASC (oldest first)
        List<Double> chronologicalScores = aiMlService.getChronologicalHistoryScores(testResident.getId());
        assertEquals(List.of(90.0, 75.0, 55.0), chronologicalScores,
                "history_scores sent to AI microservice must be strictly chronological ASC: [oldest, middle, newest]");

        // 3. Mathematical slope check: decreasing wellness (90 -> 75 -> 55) = increasing risk (10 -> 25 -> 45)
        // Slope over risk is positive (increasing risk)
        double risk1 = 100.0 - chronologicalScores.get(0); // 10.0
        double risk2 = 100.0 - chronologicalScores.get(1); // 25.0
        double risk3 = 100.0 - chronologicalScores.get(2); // 45.0
        assertTrue(risk1 < risk2 && risk2 < risk3, "Decreasing wellness must translate to monotonically increasing risk");
    }

    @Test
    @DisplayName("Verify Chronological Ordering: Increasing wellness produces ASC chronological history and decreasing risk trend")
    void testChronologicalOrdering_IncreasingWellness() {
        LocalDateTime baseTime = LocalDateTime.now().minusDays(10);

        // Save assessments with increasing wellness: T1 (oldest): 50.0, T2: 70.0, T3: 88.0
        assessmentRepository.save(Assessment.builder()
                .resident(testResident)
                .overallScore(50.0)
                .emotionalScore(50.0)
                .socialScore(50.0)
                .createdAt(baseTime.plusDays(1))
                .status(WellnessStatus.NEEDS_ATTENTION)
                .riskLevel(RiskLevel.HIGH)
                .trajectory(TrajectoryStatus.INCREASING_RISK)
                .build());

        assessmentRepository.save(Assessment.builder()
                .resident(testResident)
                .overallScore(70.0)
                .emotionalScore(70.0)
                .socialScore(70.0)
                .createdAt(baseTime.plusDays(2))
                .status(WellnessStatus.STABLE)
                .riskLevel(RiskLevel.MODERATE)
                .trajectory(TrajectoryStatus.STABLE)
                .build());

        assessmentRepository.save(Assessment.builder()
                .resident(testResident)
                .overallScore(88.0)
                .emotionalScore(88.0)
                .socialScore(88.0)
                .createdAt(baseTime.plusDays(3))
                .status(WellnessStatus.LOOKING_GOOD)
                .riskLevel(RiskLevel.LOW)
                .trajectory(TrajectoryStatus.IMPROVING)
                .build());

        // Chronological history scores extracted must be [50.0, 70.0, 88.0]
        List<Double> chronologicalScores = aiMlService.getChronologicalHistoryScores(testResident.getId());
        assertEquals(List.of(50.0, 70.0, 88.0), chronologicalScores,
                "history_scores must be strictly chronological ASC: [50.0, 70.0, 88.0]");

        // Risk check: wellness increasing (50 -> 70 -> 88) = risk decreasing (50 -> 30 -> 12)
        double risk1 = 100.0 - chronologicalScores.get(0); // 50.0
        double risk2 = 100.0 - chronologicalScores.get(1); // 30.0
        double risk3 = 100.0 - chronologicalScores.get(2); // 12.0
        assertTrue(risk1 > risk2 && risk2 > risk3, "Increasing wellness must translate to monotonically decreasing risk");
    }

    @Test
    @DisplayName("Verify Insufficient History Guard: 0 or 1 historical session returns BASELINE_ESTABLISHING")
    void testInsufficientHistoryGuard() {
        // Case A: 0 assessments
        ApiResponse<Map<String, Object>> resp0 = aiMlService.predictTrajectory(testResident.getId());
        assertNotNull(resp0);
        assertNotNull(resp0.getData());
        assertEquals("BASELINE_ESTABLISHING", resp0.getData().get("trajectoryStatus"));
        assertEquals(Boolean.TRUE, resp0.getData().get("isInsufficientHistory"));
        assertNull(resp0.getData().get("forecastTrend"));

        // Case B: 1 assessment
        assessmentRepository.save(Assessment.builder()
                .resident(testResident)
                .overallScore(80.0)
                .emotionalScore(80.0)
                .socialScore(80.0)
                .createdAt(LocalDateTime.now())
                .status(WellnessStatus.LOOKING_GOOD)
                .riskLevel(RiskLevel.LOW)
                .trajectory(TrajectoryStatus.STABLE)
                .build());

        ApiResponse<Map<String, Object>> resp1 = aiMlService.predictTrajectory(testResident.getId());
        assertNotNull(resp1);
        assertNotNull(resp1.getData());
        assertEquals("BASELINE_ESTABLISHING", resp1.getData().get("trajectoryStatus"));
        assertEquals(Boolean.TRUE, resp1.getData().get("isInsufficientHistory"));
        assertNull(resp1.getData().get("forecastTrend"));
    }
}
