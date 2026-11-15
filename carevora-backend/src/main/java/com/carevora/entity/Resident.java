package com.carevora.entity;

import com.carevora.enums.RiskLevel;
import com.carevora.enums.TrajectoryStatus;
import com.carevora.enums.WellnessStatus;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "residents")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@com.fasterxml.jackson.annotation.JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Resident {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    @com.fasterxml.jackson.annotation.JsonIgnoreProperties({"hibernateLazyInitializer", "handler", "passwordHash"})
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "elder_home_id")
    @com.fasterxml.jackson.annotation.JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private ElderHome elderHome;

    @Column(name = "room_number", nullable = false, length = 50)
    private String roomNumber;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(name = "age")
    private Integer age;

    @Column(name = "education_years")
    private Integer educationYears;

    @Column(name = "emergency_contact", length = 100)
    private String emergencyContact;

    @Enumerated(EnumType.STRING)
    @Column(name = "current_status", length = 30)
    @Builder.Default
    private WellnessStatus currentStatus = WellnessStatus.LOOKING_GOOD;

    @Enumerated(EnumType.STRING)
    @Column(name = "risk_level", length = 30)
    @Builder.Default
    private RiskLevel riskLevel = RiskLevel.LOW;

    @Enumerated(EnumType.STRING)
    @Column(name = "trajectory", length = 30)
    @Builder.Default
    private TrajectoryStatus trajectory = TrajectoryStatus.IMPROVING;

    @Column(name = "emotional_score")
    private Double emotionalScore;

    @Column(name = "social_score")
    private Double socialScore;

    @Column(name = "cognitive_score")
    private Double cognitiveScore;

    @Column(name = "last_assessment_date")
    private LocalDateTime lastAssessmentDate;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
