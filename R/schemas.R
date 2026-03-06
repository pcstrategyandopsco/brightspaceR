#' BDS Dataset Schema Registry
#'
#' Internal list of column type specifications for known Brightspace Data Set
#' datasets. Each entry contains col_types for readr, plus metadata about
#' date, boolean, and key columns.
#'
#' @keywords internal
bs_schemas <- list(

  # 1. Users
  users = list(
    col_types = readr::cols(
      UserId = readr::col_integer(),
      UserName = readr::col_character(),
      OrgDefinedId = readr::col_character(),
      FirstName = readr::col_character(),
      MiddleName = readr::col_character(),
      LastName = readr::col_character(),
      IsActive = readr::col_character(),
      Organization = readr::col_character(),
      ExternalEmail = readr::col_character(),
      SignupDate = readr::col_character(),
      FirstLoginDate = readr::col_character(),
      Version = readr::col_integer(),
      OrgRoleId = readr::col_integer(),
      LastAccessed = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("SignupDate", "FirstLoginDate", "LastAccessed"),
    bool_cols = c("IsActive"),
    key_cols = c("UserId")
  ),

  # 2. User Enrollments
  user_enrollments = list(
    col_types = readr::cols(
      OrgUnitId = readr::col_integer(),
      UserId = readr::col_integer(),
      RoleId = readr::col_integer(),
      EnrollmentDate = readr::col_character(),
      EnrollmentType = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("EnrollmentDate"),
    bool_cols = character(),
    key_cols = c("OrgUnitId", "UserId", "RoleId")
  ),

  # 3. Org Units
  org_units = list(
    col_types = readr::cols(
      OrgUnitId = readr::col_integer(),
      Organization = readr::col_character(),
      Type = readr::col_character(),
      Name = readr::col_character(),
      Code = readr::col_character(),
      StartDate = readr::col_character(),
      EndDate = readr::col_character(),
      IsActive = readr::col_character(),
      IsDeleted = readr::col_character(),
      CreatedDate = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("StartDate", "EndDate", "CreatedDate"),
    bool_cols = c("IsActive", "IsDeleted"),
    key_cols = c("OrgUnitId")
  ),

  # 4. Org Unit Types
  org_unit_types = list(
    col_types = readr::cols(
      OrgUnitTypeId = readr::col_integer(),
      Name = readr::col_character(),
      Description = readr::col_character(),
      SortOrder = readr::col_integer(),
      .default = readr::col_character()
    ),
    date_cols = character(),
    bool_cols = character(),
    key_cols = c("OrgUnitTypeId")
  ),

  # 5. Organizational Unit Ancestors
  organizational_unit_ancestors = list(
    col_types = readr::cols(
      OrgUnitId = readr::col_integer(),
      AncestorOrgUnitId = readr::col_integer(),
      .default = readr::col_character()
    ),
    date_cols = character(),
    bool_cols = character(),
    key_cols = c("OrgUnitId", "AncestorOrgUnitId")
  ),

  # 6. Enrollments and Withdrawals
  enrollments_and_withdrawals = list(
    col_types = readr::cols(
      LogId = readr::col_integer(),
      UserId = readr::col_integer(),
      OrgUnitId = readr::col_integer(),
      RoleId = readr::col_integer(),
      Action = readr::col_character(),
      ModifiedByUserId = readr::col_integer(),
      EnrollmentDate = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("EnrollmentDate"),
    bool_cols = character(),
    key_cols = c("LogId", "UserId", "OrgUnitId")
  ),

  # 7. Grade Objects
  grade_objects = list(
    col_types = readr::cols(
      GradeObjectId = readr::col_integer(),
      OrgUnitId = readr::col_integer(),
      Name = readr::col_character(),
      ParentGradeObjectId = readr::col_integer(),
      TypeName = readr::col_character(),
      MaxPoints = readr::col_double(),
      Weight = readr::col_double(),
      IsDeleted = readr::col_character(),
      IsAutoPointed = readr::col_character(),
      CreatedDate = readr::col_character(),
      StartDate = readr::col_character(),
      EndDate = readr::col_character(),
      IsFormula = readr::col_character(),
      IsBonus = readr::col_character(),
      CanExceedMaxGrade = readr::col_character(),
      ExcludeFromFinalGradeCalc = readr::col_character(),
      GradeSchemeId = readr::col_integer(),
      NumLowestGradesToDrop = readr::col_integer(),
      NumHighestGradesToDrop = readr::col_integer(),
      WeightDistributionType = readr::col_character(),
      ToolName = readr::col_character(),
      AssociatedToolItemId = readr::col_integer(),
      LastModified = readr::col_character(),
      ShortName = readr::col_character(),
      GradeObjectTypeId = readr::col_integer(),
      SortOrder = readr::col_integer(),
      DeletedDate = readr::col_character(),
      DeletedByUserId = readr::col_integer(),
      ResultId = readr::col_integer(),
      ToolId = readr::col_integer(),
      Version = readr::col_integer(),
      .default = readr::col_character()
    ),
    date_cols = c("CreatedDate", "StartDate", "EndDate", "LastModified",
                  "DeletedDate"),
    bool_cols = c("IsDeleted", "IsAutoPointed", "IsFormula", "IsBonus",
                  "CanExceedMaxGrade", "ExcludeFromFinalGradeCalc"),
    key_cols = c("GradeObjectId", "OrgUnitId")
  ),

  # 8. Grade Results
  grade_results = list(
    col_types = readr::cols(
      GradeObjectId = readr::col_integer(),
      OrgUnitId = readr::col_integer(),
      UserId = readr::col_integer(),
      PointsNumerator = readr::col_double(),
      PointsDenominator = readr::col_double(),
      WeightedNumerator = readr::col_double(),
      WeightedDenominator = readr::col_double(),
      GradeText = readr::col_character(),
      IsReleased = readr::col_character(),
      IsDropped = readr::col_character(),
      LastModified = readr::col_character(),
      LastModifiedBy = readr::col_integer(),
      Comments = readr::col_character(),
      PrivateComments = readr::col_character(),
      GradeReleasedDate = readr::col_character(),
      Version = readr::col_integer(),
      IsDeleted = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("LastModified", "GradeReleasedDate"),
    bool_cols = c("IsReleased", "IsDropped", "IsDeleted"),
    key_cols = c("GradeObjectId", "OrgUnitId", "UserId")
  ),

  # 9. Content Objects
  content_objects = list(
    col_types = readr::cols(
      ContentObjectId = readr::col_integer(),
      OrgUnitId = readr::col_integer(),
      Title = readr::col_character(),
      ContentObjectType = readr::col_character(),
      ParentContentObjectId = readr::col_integer(),
      SortOrder = readr::col_integer(),
      StartDate = readr::col_character(),
      EndDate = readr::col_character(),
      DueDate = readr::col_character(),
      IsHidden = readr::col_character(),
      IsDeleted = readr::col_character(),
      LastModified = readr::col_character(),
      CompletionType = readr::col_character(),
      Location = readr::col_character(),
      ObjectId1 = readr::col_integer(),
      ObjectId2 = readr::col_integer(),
      ObjectId3 = readr::col_character(),
      Depth = readr::col_integer(),
      ToolId = readr::col_integer(),
      ResultId = readr::col_integer(),
      DeletedDate = readr::col_character(),
      CreatedBy = readr::col_integer(),
      LastModifiedBy = readr::col_integer(),
      DeletedBy = readr::col_integer(),
      AiUtilization = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("StartDate", "EndDate", "DueDate", "LastModified",
                  "DeletedDate"),
    bool_cols = c("IsHidden", "IsDeleted", "AiUtilization"),
    key_cols = c("ContentObjectId", "OrgUnitId")
  ),

  # 10. Content User Progress
  content_user_progress = list(
    col_types = readr::cols(
      ContentObjectId = readr::col_integer(),
      UserId = readr::col_integer(),
      CompletedDate = readr::col_character(),
      LastVisited = readr::col_character(),
      TotalTime = readr::col_integer(),
      IsRead = readr::col_character(),
      NumRealVisits = readr::col_integer(),
      NumFakeVisits = readr::col_integer(),
      IsVisited = readr::col_character(),
      IsCurrentBookmark = readr::col_character(),
      IsSelfAssessComplete = readr::col_character(),
      LastModified = readr::col_character(),
      Version = readr::col_integer(),
      .default = readr::col_character()
    ),
    date_cols = c("CompletedDate", "LastVisited", "LastModified"),
    bool_cols = c("IsRead", "IsVisited", "IsCurrentBookmark",
                  "IsSelfAssessComplete"),
    key_cols = c("ContentObjectId", "UserId")
  ),

  # 11. Quiz Attempts
  quiz_attempts = list(
    col_types = readr::cols(
      AttemptId = readr::col_integer(),
      QuizId = readr::col_integer(),
      OrgUnitId = readr::col_integer(),
      UserId = readr::col_integer(),
      AttemptNumber = readr::col_integer(),
      Score = readr::col_double(),
      IsGraded = readr::col_character(),
      OldAttemptNumber = readr::col_integer(),
      PossibleScore = readr::col_integer(),
      IsRetakeIncorrectOnly = readr::col_character(),
      IsDeleted = readr::col_character(),
      TimeStarted = readr::col_character(),
      TimeCompleted = readr::col_character(),
      DueDate = readr::col_character(),
      TimeLimitEnforced = readr::col_character(),
      TimeLimit = readr::col_integer(),
      TimeLimitExceededBehaviour = readr::col_character(),
      IsSynchronous = readr::col_character(),
      DeductionPercentage = readr::col_character(),
      Version = readr::col_integer(),
      .default = readr::col_character()
    ),
    date_cols = c("TimeStarted", "TimeCompleted", "DueDate"),
    bool_cols = c("IsGraded", "IsDeleted", "TimeLimitEnforced",
                  "IsRetakeIncorrectOnly", "IsSynchronous"),
    key_cols = c("AttemptId", "QuizId", "OrgUnitId", "UserId")
  ),

  # 12. Quiz User Answers
  quiz_user_answers = list(
    col_types = readr::cols(
      AttemptId = readr::col_integer(),
      QuestionId = readr::col_integer(),
      QuestionVersionId = readr::col_integer(),
      TimeCompleted = readr::col_character(),
      QuestionNumber = readr::col_integer(),
      Comment = readr::col_character(),
      SortOrder = readr::col_integer(),
      Score = readr::col_double(),
      Page = readr::col_integer(),
      SectionId = readr::col_integer(),
      ObjectId = readr::col_integer(),
      OutOf = readr::col_double(),
      TimeStarted = readr::col_character(),
      IsBonus = readr::col_character(),
      IsDeleted = readr::col_character(),
      LastModified = readr::col_character(),
      LastModifiedBy = readr::col_integer(),
      QuizTimeCompleted = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("TimeCompleted", "TimeStarted", "LastModified",
                  "QuizTimeCompleted"),
    bool_cols = c("IsBonus", "IsDeleted"),
    key_cols = c("AttemptId", "QuestionId")
  ),

  # 13. Discussion Posts
  discussion_posts = list(
    col_types = readr::cols(
      PostId = readr::col_integer(),
      OrgUnitId = readr::col_integer(),
      TopicId = readr::col_integer(),
      UserId = readr::col_integer(),
      ParentPostId = readr::col_integer(),
      ThreadId = readr::col_integer(),
      DatePosted = readr::col_character(),
      WordCount = readr::col_integer(),
      IsDeleted = readr::col_character(),
      IsReply = readr::col_character(),
      NumReplies = readr::col_integer(),
      RatingSum = readr::col_double(),
      NumRatings = readr::col_integer(),
      Score = readr::col_double(),
      LastEditDate = readr::col_character(),
      SortOrder = readr::col_integer(),
      Depth = readr::col_integer(),
      Thread = readr::col_character(),
      AttachmentCount = readr::col_integer(),
      Version = readr::col_integer(),
      .default = readr::col_character()
    ),
    date_cols = c("DatePosted", "LastEditDate"),
    bool_cols = c("IsDeleted", "IsReply"),
    key_cols = c("PostId", "OrgUnitId", "TopicId", "UserId")
  ),

  # 14. Discussion Topics
  discussion_topics = list(
    col_types = readr::cols(
      TopicId = readr::col_integer(),
      ForumId = readr::col_integer(),
      OrgUnitId = readr::col_integer(),
      Name = readr::col_character(),
      Description = readr::col_character(),
      IsHidden = readr::col_character(),
      MustPostToParticipate = readr::col_character(),
      AllowAnon = readr::col_character(),
      RequiresApproval = readr::col_character(),
      IsDeleted = readr::col_character(),
      StartDate = readr::col_character(),
      EndDate = readr::col_character(),
      LastPostDate = readr::col_character(),
      LastPostUserId = readr::col_integer(),
      NumViews = readr::col_integer(),
      SortOrder = readr::col_integer(),
      DeletedDate = readr::col_character(),
      DeletedByUserId = readr::col_integer(),
      GradeItemId = readr::col_integer(),
      ScoreOutOf = readr::col_double(),
      ScoreCalculationMethod = readr::col_character(),
      IncludeNonScoredValues = readr::col_character(),
      Version = readr::col_integer(),
      ResultId = readr::col_integer(),
      StartDateAvailabilityType = readr::col_integer(),
      EndDateAvailabilityType = readr::col_integer(),
      AiUtilization = readr::col_character(),
      DueDate = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("StartDate", "EndDate", "LastPostDate", "DeletedDate",
                  "DueDate"),
    bool_cols = c("IsHidden", "MustPostToParticipate", "AllowAnon",
                  "RequiresApproval", "IsDeleted", "IncludeNonScoredValues",
                  "AiUtilization"),
    key_cols = c("TopicId", "ForumId", "OrgUnitId")
  ),

  # 15. Assignment Submissions
  assignment_submissions = list(
    col_types = readr::cols(
      DropboxId = readr::col_integer(),
      OrgUnitId = readr::col_integer(),
      SubmitterId = readr::col_integer(),
      SubmitterType = readr::col_character(),
      Score = readr::col_double(),
      IsGraded = readr::col_character(),
      FileSubmissionCount = readr::col_integer(),
      TotalFileSize = readr::col_double(),
      FeedbackUserId = readr::col_integer(),
      FeedbackIsRead = readr::col_character(),
      LastSubmissionDate = readr::col_character(),
      Feedback = readr::col_character(),
      FeedbackLastModified = readr::col_character(),
      FeedbackReadDate = readr::col_character(),
      CompletionDate = readr::col_character(),
      IsDeleted = readr::col_character(),
      Version = readr::col_integer(),
      .default = readr::col_character()
    ),
    date_cols = c("LastSubmissionDate", "FeedbackLastModified",
                  "FeedbackReadDate", "CompletionDate"),
    bool_cols = c("IsGraded", "FeedbackIsRead", "IsDeleted"),
    key_cols = c("DropboxId", "OrgUnitId", "SubmitterId")
  ),

  # 16. Attendance Registers
  attendance_registers = list(
    col_types = readr::cols(
      AttendanceRegisterId = readr::col_integer(),
      OrgUnitId = readr::col_integer(),
      Name = readr::col_character(),
      Description = readr::col_character(),
      SchemeId = readr::col_integer(),
      IncludeAllUsers = readr::col_character(),
      IsVisible = readr::col_character(),
      CauseForConcern = readr::col_character(),
      Version = readr::col_integer(),
      DateDeleted = readr::col_character(),
      DeletedBy = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("DateDeleted"),
    bool_cols = c("IncludeAllUsers", "IsVisible"),
    key_cols = c("AttendanceRegisterId", "OrgUnitId")
  ),

  # 17. Attendance Records
  attendance_records = list(
    col_types = readr::cols(
      AttendanceRegisterId = readr::col_integer(),
      SessionId = readr::col_integer(),
      UserId = readr::col_integer(),
      OrgUnitId = readr::col_integer(),
      StatusId = readr::col_integer(),
      StatusName = readr::col_character(),
      TimeRecorded = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("TimeRecorded"),
    bool_cols = character(),
    key_cols = c("AttendanceRegisterId", "SessionId", "UserId")
  ),

  # 18. Role Details
  role_details = list(
    col_types = readr::cols(
      RoleId = readr::col_integer(),
      RoleName = readr::col_character(),
      Description = readr::col_character(),
      IsCascading = readr::col_character(),
      InClassList = readr::col_character(),
      ClassListRoleName = readr::col_character(),
      ClassListShowGroups = readr::col_character(),
      ClassListShowSections = readr::col_character(),
      ClassListDisplayRole = readr::col_character(),
      AccessInactiveCo = readr::col_character(),
      HasSpecialAccess = readr::col_character(),
      AddToCourseOfferingGroups = readr::col_character(),
      CanBeAutoEnrolledIntoGroups = readr::col_character(),
      AddToCourseOfferingSections = readr::col_character(),
      CanBeAutoEnrolledIntoSections = readr::col_character(),
      AccessPastCourses = readr::col_character(),
      AccessFutureCourses = readr::col_character(),
      SortOrder = readr::col_integer(),
      ShowInContent = readr::col_character(),
      ShowInDiscussionAssess = readr::col_character(),
      ShowInDiscussionStats = readr::col_character(),
      ShowInGrades = readr::col_character(),
      ShowInAttendance = readr::col_character(),
      AllowSelfEnrollInGroups = readr::col_character(),
      ShowInRegistration = readr::col_character(),
      ShowInUserProgress = readr::col_character(),
      RoleAlias = readr::col_character(),
      RoleCode = readr::col_character(),
      LastModifiedDate = readr::col_character(),
      DeletedBy = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("LastModifiedDate"),
    bool_cols = c("IsCascading", "InClassList", "ClassListShowGroups",
                  "ClassListShowSections", "ClassListDisplayRole",
                  "AccessInactiveCo", "HasSpecialAccess",
                  "AddToCourseOfferingGroups", "CanBeAutoEnrolledIntoGroups",
                  "AddToCourseOfferingSections", "CanBeAutoEnrolledIntoSections",
                  "AccessPastCourses", "AccessFutureCourses",
                  "ShowInContent", "ShowInDiscussionAssess",
                  "ShowInDiscussionStats", "ShowInGrades", "ShowInAttendance",
                  "AllowSelfEnrollInGroups", "ShowInRegistration",
                  "ShowInUserProgress"),
    key_cols = c("RoleId")
  ),

  # 19. Course Offerings
  course_offerings = list(
    col_types = readr::cols(
      OfferingId = readr::col_integer(),
      CourseCode = readr::col_character(),
      CourseName = readr::col_character(),
      OrgUnitId = readr::col_integer(),
      TemplateId = readr::col_integer(),
      SemesterId = readr::col_integer(),
      DepartmentId = readr::col_integer(),
      StartDate = readr::col_character(),
      EndDate = readr::col_character(),
      IsActive = readr::col_character(),
      IsDeleted = readr::col_character(),
      CreatedDate = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("StartDate", "EndDate", "CreatedDate"),
    bool_cols = c("IsActive", "IsDeleted"),
    key_cols = c("OfferingId", "OrgUnitId")
  ),

  # 20. Final Grades
  final_grades = list(
    col_types = readr::cols(
      OrgUnitId = readr::col_integer(),
      UserId = readr::col_integer(),
      FinalCalculatedGrade = readr::col_double(),
      FinalAdjustedGrade = readr::col_double(),
      FinalGradeSchemeSymbol = readr::col_character(),
      IsReleased = readr::col_character(),
      LastModified = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("LastModified"),
    bool_cols = c("IsReleased"),
    key_cols = c("OrgUnitId", "UserId")
  )
)

#' Get the schema for a dataset
#'
#' @param dataset_name Name of the dataset (will be normalized to snake_case).
#'
#' @return A schema list, or `NULL` if no schema is registered.
#' @export
#'
#' @examples
#' bs_get_schema("Users")
#' bs_get_schema("Grade Results")
bs_get_schema <- function(dataset_name) {
  key <- normalize_dataset_name(dataset_name)
  bs_schemas[[key]]
}

#' List all registered dataset schemas
#'
#' @return A character vector of registered dataset names (snake_case).
#' @export
#'
#' @examples
#' bs_list_schemas()
bs_list_schemas <- function() {
  names(bs_schemas)
}

#' Get key columns for a dataset
#'
#' Returns the primary/foreign key column names for a known dataset.
#'
#' @param dataset_name Name of the dataset.
#'
#' @return Character vector of key column names (snake_case), or `NULL`.
#' @keywords internal
bs_key_cols <- function(dataset_name) {
  schema <- bs_get_schema(dataset_name)
  if (!is.null(schema) && !is.null(schema$key_cols)) {
    to_snake_case(schema$key_cols)
  } else {
    NULL
  }
}
