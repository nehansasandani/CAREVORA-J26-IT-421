package com.carevora.dto.user;

import com.carevora.enums.RiskLevel;
import com.carevora.enums.UserRole;
import com.carevora.enums.WellnessStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserSummaryResponse {
    private Long id;
    private String name;
    private String email;
    private UserRole role;
    private Boolean active;
    private Long elderHomeId;
    private String elderHomeName;
    private Long residentId;
    private Long caregiverId;
    private String roomNumber;
    private Integer age;
    private Integer educationYears;
    private String avatarUrl;
    private WellnessStatus currentStatus;
    private RiskLevel riskLevel;
    private String staffCode;
    private String title;
    private String department;
    private LocalDateTime createdAt;
}
