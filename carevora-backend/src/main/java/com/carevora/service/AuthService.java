package com.carevora.service;

import com.carevora.dto.ApiResponse;
import com.carevora.dto.auth.FacilityAccessRequest;
import com.carevora.dto.auth.LoginRequest;
import com.carevora.dto.auth.LoginResponse;
import com.carevora.dto.auth.RegisterRequest;
import com.carevora.dto.elderhome.ElderHomeResponse;
import com.carevora.entity.Caregiver;
import com.carevora.entity.ElderHome;
import com.carevora.entity.Resident;
import com.carevora.entity.User;
import com.carevora.enums.RiskLevel;
import com.carevora.enums.TrajectoryStatus;
import com.carevora.enums.UserRole;
import com.carevora.enums.WellnessStatus;
import com.carevora.exception.BadRequestException;
import com.carevora.repository.CaregiverRepository;
import com.carevora.repository.ElderHomeRepository;
import com.carevora.repository.ResidentRepository;
import com.carevora.repository.UserRepository;
import com.carevora.security.JwtService;
import com.carevora.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final ResidentRepository residentRepository;
    private final CaregiverRepository caregiverRepository;
    private final ElderHomeRepository elderHomeRepository;
    private final ElderHomeService elderHomeService;
    private final AuthenticationManager authenticationManager;
    private final UserDetailsService userDetailsService;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    @Transactional(readOnly = true)
    public ApiResponse<LoginResponse> login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new BadRequestException("User not found"));

        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getEmail());
        String token = jwtService.generateToken(userDetails);

        Long residentId = null;
        Long caregiverId = null;
        Long elderHomeId = null;
        String elderHomeName = null;

        Optional<Resident> resOpt = residentRepository.findByUserId(user.getId());
        if (resOpt.isPresent()) {
            Resident r = resOpt.get();
            residentId = r.getId();
            if (r.getElderHome() != null) {
                elderHomeId = r.getElderHome().getId();
                elderHomeName = r.getElderHome().getName();
            }
        }

        Optional<Caregiver> cgOpt = caregiverRepository.findByUserId(user.getId());
        if (cgOpt.isPresent()) {
            Caregiver cg = cgOpt.get();
            caregiverId = cg.getId();
            if (cg.getElderHome() != null) {
                elderHomeId = cg.getElderHome().getId();
                elderHomeName = cg.getElderHome().getName();
            }
        }

        LoginResponse response = LoginResponse.builder()
                .token(token)
                .id(user.getId())
                .email(user.getEmail())
                .name(user.getFullName())
                .role(user.getRole())
                .avatarUrl(user.getAvatarUrl())
                .residentId(residentId)
                .caregiverId(caregiverId)
                .elderHomeId(elderHomeId)
                .elderHomeName(elderHomeName)
                .build();

        return ApiResponse.ok(response, "Login successful");
    }

    @Transactional
    public ApiResponse<LoginResponse> register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail().trim().toLowerCase())) {
            throw new BadRequestException("Email is already registered: " + request.getEmail());
        }

        String[] names = splitFullName(request.getFullName().trim());
        String firstName = names[0];
        String lastName = names[1];

        User user = User.builder()
                .email(request.getEmail().trim().toLowerCase())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .firstName(firstName)
                .lastName(lastName)
                .role(request.getRole())
                .avatarUrl(request.getAvatarUrl())
                .active(true)
                .build();
        userRepository.save(user);

        ElderHome elderHome = null;
        if (request.getElderHomeId() != null) {
            elderHome = elderHomeRepository.findById(request.getElderHomeId())
                    .orElseThrow(() -> new BadRequestException("Selected elder home not found with id: " + request.getElderHomeId()));
        }

        Long residentId = null;
        Long caregiverId = null;

        if (request.getRole() == UserRole.ELDER || request.getRole() == UserRole.RESIDENT) {
            Resident resident = Resident.builder()
                    .user(user)
                    .elderHome(elderHome)
                    .roomNumber(request.getRoomNumber() != null ? request.getRoomNumber() : "Unassigned")
                    .age(request.getAge() != null ? request.getAge() : 75)
                    .educationYears(request.getEducationYears() != null ? request.getEducationYears() : 12)
                    .emergencyContact(request.getEmergencyContact())
                    .currentStatus(WellnessStatus.LOOKING_GOOD)
                    .riskLevel(RiskLevel.LOW)
                    .trajectory(TrajectoryStatus.STABLE)
                    .emotionalScore(80.0)
                    .lastAssessmentDate(LocalDateTime.now())
                    .build();
            residentRepository.save(resident);
            residentId = resident.getId();
        } else if (request.getRole() == UserRole.CAREGIVER) {
            Caregiver caregiver = Caregiver.builder()
                    .user(user)
                    .elderHome(elderHome)
                    .staffCode(request.getStaffCode() != null ? request.getStaffCode() : "CG-" + (100 + user.getId()))
                    .title(request.getTitle() != null ? request.getTitle() : "Care Coordinator")
                    .department(request.getDepartment() != null ? request.getDepartment() : "General Elderly Care")
                    .build();
            caregiverRepository.save(caregiver);
            caregiverId = caregiver.getId();
        }

        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getEmail());
        String token = jwtService.generateToken(userDetails);

        LoginResponse response = LoginResponse.builder()
                .token(token)
                .id(user.getId())
                .email(user.getEmail())
                .name(user.getFullName())
                .role(user.getRole())
                .avatarUrl(user.getAvatarUrl())
                .residentId(residentId)
                .caregiverId(caregiverId)
                .elderHomeId(elderHome != null ? elderHome.getId() : null)
                .elderHomeName(elderHome != null ? elderHome.getName() : null)
                .build();

        return ApiResponse.ok(response, "Account registered and assigned successfully");
    }

    @Transactional
    public ApiResponse<ElderHomeResponse> requestFacilityAccess(FacilityAccessRequest request) {
        return elderHomeService.requestFacilityAccess(request);
    }

    @Transactional(readOnly = true)
    public ApiResponse<LoginResponse> getCurrentUserProfile() {
        User user = SecurityUtils.getCurrentUser(userRepository)
                .orElseThrow(() -> new BadRequestException("User session expired or not authenticated"));

        Long residentId = residentRepository.findByUserId(user.getId()).map(Resident::getId).orElse(null);
        Long caregiverId = caregiverRepository.findByUserId(user.getId()).map(Caregiver::getId).orElse(null);

        Long elderHomeId = null;
        String elderHomeName = null;

        if (residentId != null) {
            Resident r = residentRepository.findById(residentId).orElse(null);
            if (r != null && r.getElderHome() != null) {
                elderHomeId = r.getElderHome().getId();
                elderHomeName = r.getElderHome().getName();
            }
        } else if (caregiverId != null) {
            Caregiver cg = caregiverRepository.findById(caregiverId).orElse(null);
            if (cg != null && cg.getElderHome() != null) {
                elderHomeId = cg.getElderHome().getId();
                elderHomeName = cg.getElderHome().getName();
            }
        }

        LoginResponse response = LoginResponse.builder()
                .id(user.getId())
                .email(user.getEmail())
                .name(user.getFullName())
                .role(user.getRole())
                .avatarUrl(user.getAvatarUrl())
                .residentId(residentId)
                .caregiverId(caregiverId)
                .elderHomeId(elderHomeId)
                .elderHomeName(elderHomeName)
                .build();

        return ApiResponse.ok(response);
    }

    private String[] splitFullName(String fullName) {
        String[] parts = fullName.split("\\s+");
        if (parts.length == 1) {
            return new String[]{parts[0], ""};
        }
        String first = parts[0];
        StringBuilder last = new StringBuilder();
        for (int i = 1; i < parts.length; i++) {
            if (i > 1) last.append(" ");
            last.append(parts[i]);
        }
        return new String[]{first, last.toString()};
    }
}
