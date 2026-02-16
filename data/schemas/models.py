"""
ARTI 2026 - SQLAlchemy Modelleri
==================================
ORM modelleri - PostgreSQL cedvelleri ile islemek ucun.
"""

from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime, Date,
    Text, JSON, ForeignKey, CheckConstraint, Index
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

Base = declarative_base()


def generate_uuid():
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    user_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    role = Column(String(50), nullable=False)
    phone = Column(String(20))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class School(Base):
    __tablename__ = "schools"

    school_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    school_name = Column(String(255), nullable=False)
    school_type = Column(String(50))
    region = Column(String(100))
    district = Column(String(100))
    address = Column(Text)
    phone = Column(String(20))
    email = Column(String(255))
    director_name = Column(String(255))
    student_count = Column(Integer, default=0)
    teacher_count = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    students = relationship("Student", back_populates="school")
    teachers = relationship("Teacher", back_populates="school")


class Student(Base):
    __tablename__ = "students"

    student_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"))
    school_id = Column(UUID(as_uuid=True), ForeignKey("schools.school_id"))
    grade_level = Column(Integer)
    class_name = Column(String(10))
    full_name = Column(String(255), nullable=False)
    birth_date = Column(Date)
    gender = Column(String(10))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    school = relationship("School", back_populates="students")
    exam_sessions = relationship("ExamSession", back_populates="student")


class Teacher(Base):
    __tablename__ = "teachers"

    teacher_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"))
    school_id = Column(UUID(as_uuid=True), ForeignKey("schools.school_id"))
    subject = Column(String(100), nullable=False)
    qualification = Column(String(100))
    experience_years = Column(Integer, default=0)
    certification_level = Column(String(50))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    school = relationship("School", back_populates="teachers")


class Item(Base):
    __tablename__ = "items"

    item_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    item_code = Column(String(50), unique=True, nullable=False)
    subject = Column(String(100), nullable=False)
    topic = Column(String(200))
    grade_level = Column(Integer)
    difficulty = Column(String(20))
    question_text = Column(Text, nullable=False)
    options = Column(JSON, nullable=False)
    correct_answer = Column(Integer, nullable=False)
    explanation = Column(Text)
    irt_a = Column(Float)
    irt_b = Column(Float)
    irt_c = Column(Float)
    irt_calibrated = Column(Boolean, default=False)
    status = Column(String(20), default="draft")
    usage_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)


class Exam(Base):
    __tablename__ = "exams"

    exam_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    exam_code = Column(String(50), unique=True, nullable=False)
    exam_type = Column(String(50), nullable=False)
    title = Column(String(255), nullable=False)
    subject = Column(String(100))
    grade_level = Column(Integer)
    total_questions = Column(Integer)
    duration_minutes = Column(Integer)
    passing_score = Column(Float)
    is_active = Column(Boolean, default=True)
    scheduled_date = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)

    sessions = relationship("ExamSession", back_populates="exam")


class ExamSession(Base):
    __tablename__ = "exam_sessions"

    session_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    exam_id = Column(UUID(as_uuid=True), ForeignKey("exams.exam_id"))
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.student_id"))
    school_id = Column(UUID(as_uuid=True), ForeignKey("schools.school_id"))
    theta = Column(Float)
    raw_score = Column(Integer)
    max_score = Column(Integer)
    percentage = Column(Float)
    se = Column(Float)
    performance_level = Column(String(50))
    started_at = Column(DateTime)
    completed_at = Column(DateTime)
    duration_seconds = Column(Integer)
    items_administered = Column(Integer)
    responses = Column(JSON)
    theta_history = Column(JSON)
    status = Column(String(20), default="active")
    created_at = Column(DateTime, default=datetime.utcnow)

    exam = relationship("Exam", back_populates="sessions")
    student = relationship("Student", back_populates="exam_sessions")
