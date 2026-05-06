import edu.nyu.aquery.Aquery
import edu.nyu.aquery.codegen.KdbGenerator
import edu.nyu.aquery.parse.AqueryParser

import java.io.{File, PrintWriter}
import java.io.File.createTempFile

import org.scalatest.{Ignore, FunSuite}

import scala.io.Source
import scala.sys.process._

/**
 * All tests here focus on making sure the result of running the code is the same as if
 * we wrote equivalent q code. We don't test the exact form of the code generated, as this
 * is likely to change throughout time.
 *
 * If a test requires any data or pre-defined functions, these should be added to the aquery code
 * (wrapped in <q> </q> if necessary), as this is run first in the q test harness (runner.q).
 *
 * To run these tests, you need q in your PATH, so that Scala can launch an external q process
 * for each test.
 */
class KdbGeneratorTestSuite extends FunSuite {
  // q script that wraps running tests
  val runner = getClass.getResource("q/runner.q").getFile

  // create the running command
  def cmd(afile: String, qfile: String, test: String): Seq[String] =
    List("q", runner, "-aquery", afile, "-kdb", qfile, "-test", test)

  // trim code to avoid issues on the q side
  def cleanCode(str: String): String =
    str.split("\n").map { l =>
      val t = l.trim
      if (t.startsWith(".")) t else " " + t
    }.mkString("\n")

  // write code to files, translate in case of aquery
  def toFiles(acode: String, qcode: String, optimize: Boolean): (File, File) = {
    val afile = createTempFile("aquery_", ".a")
    val tfile = createTempFile("translated_", ".q")
    val qfile = createTempFile("kdb_", ".q")

    val awriter = new PrintWriter(afile)
    val qwriter = new PrintWriter(qfile)

    awriter.write(cleanCode(acode))
    awriter.close()

    qwriter.write(cleanCode(qcode))
    qwriter.close()

    // translate
    val optCode = if (optimize) "1" else "0"
    Aquery.main(Array("-a", optCode, "-c", "-o", tfile.getAbsolutePath, afile.getAbsolutePath))
    // want translated and kdb file
    (tfile, qfile)
  }

  // read code from a file
  def getCode(f: String): String = {
    val file = getClass.getResource(f).getFile
    Source.fromFile(file).getLines().mkString("\n")
  }

  // run code using external q process
  def run(acode: String, qcode: String, test: String, optimize: Boolean): (Boolean, String)= {
    val (afile, qfile) = toFiles(acode, qcode, optimize)
    val c = cmd(afile.getAbsolutePath, qfile.getAbsolutePath, test)
    val stdout = new StringBuffer
    val success = c.run(BasicIO(withIn = false, stdout, None)).exitValue() == 0
    if (success) {
      afile.deleteOnExit()
      qfile.deleteOnExit()
    }
    (success, "\n" + stdout.toString)
  }

  def generate(acode: String): String = {
    val prog = AqueryParser(cleanCode(acode)) match {
      case AqueryParser.Success(p, _) => p
      case fail => scala.sys.error("parse failed: " + fail.toString)
    }
    KdbGenerator.generate(prog)
  }

  test("simple expressions/UDF") {
    val acode =
      """
        FUNCTION f(){
          x := 100 * 2 - 3;
          y := x ^ 3;
          l := LIST(1,2,3,4,5,6);
          z :=
            CASE l
              WHEN 2 THEN -1
              WHEN 3 THEN 100
              ELSE 200
            END;
          w := sums(2, l);
          LIST(sqrt(y), z, w)}
          <q> .aq.f:f; </q>
      """
    val qcode =
      """
        .kdb.f:{[]
          x:-3+100*2;
          y:x xexp 3;
          l:1 2 3 4 5 6;
          z:200^(2 3!-1 100) l;
          w:2 msum l;
          (sqrt y; z; w)};
      """

    val tests = "f"
    val (passed0, msg0) = run(acode, qcode, tests, optimize = false)
    assert(passed0, "basic: " + msg0)

    val (passed1, msg1) = run(acode, qcode, tests, optimize = true)
    assert(passed1, "optimized: " + msg1)
  }

  test("create") {
    val acode =
      """
        <q> base:([]c1:1000?100; c2:1000?100; c3:1000?100) </q>
        CREATE TABLE aq_t1 (c1 INT, c2 STRING, c3 BOOLEAN)
        CREATE TABLE aq_t2
          SELECT
          c1 * 2 as c1, sums(c2) as c2, max(c3) as max_c3
          FROM base ASSUMING ASC c3 WHERE c1 > 10
          GROUP BY c1

        <q>.aq.c1:{aq_t1}; .aq.c2:{aq_t2};</q>
      """
    val qcode =
      """
        .kdb.c1:{([]c1:`long$();c2:`$();c3:`boolean$())};
        .kdb.c2:{
          select c1:c1 * 2, c2, max_c3:c3 from select sums c2, max c3 by c1 from `c3 xasc base where c1 > 10
          }
      """

    val tests = "c1, c2"
    val (passed0, msg0) = run(acode, qcode, tests, optimize = false)
    assert(passed0, "basic: " + msg0)

    val (passed1, msg1) = run(acode, qcode, tests, optimize = true)
    assert(passed1, "optimized: " + msg1)
  }

  test("insert") {
    val acode =
      """
         <q> base:([]c2:1 2 3 4; c3:100 200 300 400) </q>
         CREATE TABLE t (c1 INT, c2 INT, c3 STRING)
         INSERT INTO t VALUES(1, 2, "c")
         INSERT INTO t VALUES(10, 20, "C")
         INSERT INTO t(c1, c2, c3)
          SELECT c2, c2, "this is a test" from base

         SELECT * FROM t
      """
    val qcode =
      """
        .kdb.q0:{
          t:([]c1:`long$(); c2:`long$(); c3:`$());
          t:t upsert (1;2;`c);
          t:t upsert (10;20;`C);
          t:t upsert select c1:c2, c2, c3:`$"this is a test" from base;
          t
          }
      """

    val tests = "q0"
    val (passed0, msg0) = run(acode, qcode, tests, optimize = false)
    assert(passed0, "basic: " + msg0)

    val (passed1, msg1) = run(acode, qcode, tests, optimize = true)
    assert(passed1, "optimized: " + msg1)
  }

  test("load/save") {
    val acode =
      """
         CREATE TABLE t (c1 INT, c2 INT, c3 STRING)
         INSERT INTO t VALUES(1, 2, "c")
         INSERT INTO t VALUES(10, 20, "C")

         SELECT * FROM t
         INTO OUTFILE "my_test_file.csv" FIELDS TERMINATED BY ","

         CREATE TABLE t2(c1 INT, c2 INT, c3 STRING)
         LOAD DATA INFILE "my_test_file.csv"
         INTO TABLE t2 FIELDS TERMINATED BY ","

        <q> .aq.q0:{t2}; system "rm -f my_test_file.csv" </q>
      """
    val qcode = ".kdb.q0:{t}"

    val tests = "q0"
    val (passed0, msg0) = run(acode, qcode, tests, optimize = false)
    assert(passed0, "basic: " + msg0)

    val (passed1, msg1) = run(acode, qcode, tests, optimize = true)
    assert(passed1, "optimized: " + msg1)
  }

  test("update/delete") {
    val acode =
      """
        <q> base:([]c1:1000?100; c2:1000?100; c3:1000?100); </q>

        CREATE TABLE upd_t
          SELECT * FROM base

        CREATE TABLE del_t
          SELECT * FROM base

         UPDATE upd_t
         SET c1 = c1 * 2, c3 = CASE WHEN c3 > 50 THEN 1 else -1 END
         ASSUMING ASC c1

         DELETE FROM del_t GROUP BY c1 HAVING COUNT(c2) > 4

        <q>.aq.c1:{upd_t}; .aq.c2:{del_t};</q>
      """
    val qcode =
      """
        .kdb.c1:{0N!update c1:c1 * 2, c3:?[c3 > 50;1;-1] from `c1 xasc base};
        .kdb.c2:{0N!delete from base where 4 <(count;c2) fby c1}
      """

    val tests = "c1, c2"
    val (passed0, msg0) = run(acode, qcode, tests, optimize = false)
    assert(passed0, "basic: " + msg0)

    val (passed1, msg1) = run(acode, qcode, tests, optimize = true)
    assert(passed1, "optimized: " + msg1)
  }

  test("trigger registration codegen") {
    val acode =
      """
        CREATE TRIGGER trg_sync
        AFTER UPDATE ON table1
        REFERENCING NEW TABLE AS inserted
        DO UPDATE table2 SET qty = inserted.qty, note = inserted.note WHERE table2.id = inserted.id
      """
    val code = generate(acode)
    assert(code.contains(".trg.register[`table1;`update;`after;`trg_sync;100;`.trg.gen_trg_sync_0];"))
    assert(code.contains(".trg.syncMappedUpdateRowsTo[aq__t"))
    assert(code.contains(";`table2;`id;`id;`qty`note!`qty`note];"))
    assert(code.contains("cross aq__t"))
    assert(code.contains("NEW TABLE AS inserted"))
    assert(!code.contains("value ctx`bodyCode;"))
  }

  test("trigger registration codegen multi-key") {
    val acode =
      """
        CREATE TRIGGER trg_sync
        AFTER UPDATE ON table1
        REFERENCING NEW TABLE AS inserted
        DO UPDATE table2
           SET qty = inserted.qty, note = inserted.note
           WHERE table2.id = inserted.id AND table2.subid = inserted.subid
      """
    val code = generate(acode)
    assert(code.contains(".trg.syncMappedUpdateRowsTo[aq__t"))
    assert(code.contains(";`table2;`id`subid;`id`subid;`qty`note!`qty`note];"))
    assert(code.contains("((`id);(`subid);(`qty);(`note))!"))
  }

  test("trigger registration codegen expression mapping") {
    val acode =
      """
        CREATE TRIGGER trg_sync
        AFTER UPDATE ON table1
        REFERENCING NEW TABLE AS inserted
        DO UPDATE table2
           SET qty = inserted.qty + 1, note = inserted.note
           WHERE table2.id = inserted.id
      """
    val code = generate(acode)
    assert(code.contains(".trg.syncMappedUpdateRowsTo[aq__t"))
    assert(code.contains(";`table2;`id;`id;`qty`note!`qty`note];"))
    assert(code.contains("inserted"))
    assert(code.contains("(+; {x^.aq.cd x} `inserted.qty; 1)"))
  }

  test("trigger registration codegen mixed target and transition expression") {
    val acode =
      """
        CREATE TRIGGER trg_sync
        AFTER UPDATE ON table1
        REFERENCING NEW TABLE AS inserted
        DO UPDATE table2
           SET qty = table2.qty + inserted.delta
           WHERE table2.id = inserted.id AND table2.qty < inserted.limit
      """
    val code = generate(acode)
    assert(code.contains("cross aq__t"))
    assert(code.contains("{x^.aq.cd x} `table2.id"))
    assert(code.contains("(+; {x^.aq.cd x} `table2.qty; {x^.aq.cd x} `inserted.delta)"))
    assert(code.contains("(<; {x^.aq.cd x} `table2.qty; {x^.aq.cd x} `inserted.limit)"))
    assert(code.contains(".trg.syncMappedUpdateRowsTo[aq__t"))
    assert(code.contains(";`table2;`id;`id;"))
  }

  test("trigger registration codegen complex delete where") {
    val acode =
      """
        CREATE TRIGGER trg_sync
        AFTER DELETE ON table1
        REFERENCING OLD TABLE AS deleted
        DO DELETE FROM table2
           WHERE table2.id = deleted.id AND table2.qty < deleted.limit
      """
    val code = generate(acode)
    assert(code.contains("{x^.aq.cd x} `table2.id"))
    assert(code.contains("(<; {x^.aq.cd x} `table2.qty; {x^.aq.cd x} `deleted.limit)"))
    assert(code.contains(".trg.syncMappedDeleteRowsFrom[aq__t"))
    assert(code.contains(";`table2;`id;`id];"))
  }

  test("trigger registration codegen old-table update mapping") {
    val acode =
      """
        CREATE TRIGGER trg_sync
        AFTER UPDATE ON table1
        REFERENCING OLD TABLE AS deleted
        DO UPDATE table2
           SET qty = deleted.qty, note = deleted.note
           WHERE table2.id = deleted.id
      """
    val code = generate(acode)
    assert(code.contains("deleted:.aq.initTable[.trg.oldRows ctx;\"deleted\";0b];"))
    assert(code.contains(".trg.syncMappedUpdateRowsTo[aq__t"))
    assert(code.contains(";`table2;`id;`id;`qty`note!`qty`note];"))
    assert(code.contains("OLD TABLE AS deleted"))
  }

  test("trigger registration codegen after delete old-table mapping") {
    val acode =
      """
        CREATE TRIGGER trg_sync
        AFTER DELETE ON table1
        REFERENCING OLD TABLE AS deleted
        DO UPDATE table2
           SET qty = deleted.qty, note = deleted.note
           WHERE table2.id = deleted.id
      """
    val code = generate(acode)
    assert(code.contains(".trg.register[`table1;`delete;`after;`trg_sync;100;`.trg.gen_trg_sync_0];"))
    assert(code.contains("deleted:.aq.initTable[.trg.oldRows ctx;\"deleted\";0b];"))
    assert(code.contains(".trg.syncMappedUpdateRowsTo[aq__t"))
    assert(code.contains(";`table2;`id;`id;`qty`note!`qty`note];"))
  }

  test("trigger registration codegen delete-sync mapping") {
    val acode =
      """
        CREATE TRIGGER trg_sync
        AFTER DELETE ON table1
        REFERENCING OLD TABLE AS deleted
        DO DELETE FROM table2 WHERE table2.id = deleted.id
      """
    val code = generate(acode)
    assert(code.contains(".trg.register[`table1;`delete;`after;`trg_sync;100;`.trg.gen_trg_sync_0];"))
    assert(code.contains("deleted:.aq.initTable[.trg.oldRows ctx;\"deleted\";0b];"))
    assert(code.contains(".trg.syncMappedDeleteRowsFrom[aq__t"))
    assert(code.contains(";`table2;`id;`id];"))
  }

  test("trigger registration codegen before delete old-table binding") {
    val acode =
      """
        CREATE TRIGGER trg_sync
        BEFORE DELETE ON table1
        REFERENCING OLD TABLE AS deleted
        DO INSERT INTO audit SELECT * FROM deleted
      """
    val code = generate(acode)
    assert(code.contains(".trg.register[`table1;`delete;`before;`trg_sync;100;`.trg.gen_trg_sync_0];"))
    assert(code.contains("deleted:.aq.initTable[.trg.oldRows ctx;\"deleted\";0b];"))
  }

  test("drop trigger codegen") {
    val code = generate("DROP TRIGGER trg_sync")
    assert(code.contains(".trg.drop[`trg_sync];"))
  }

  test("simple queries") {
    val acode =
      """
        <q> base:([]c1:1000?100; c2:1000?100; c3:1000?100); </q>

        CREATE TABLE upd_t
          SELECT * FROM base

        CREATE TABLE del_t
          SELECT * FROM base

         UPDATE upd_t
         SET c1 = c1 * 2, c3 = CASE WHEN c3 > 50 THEN 1 else -1 END
         ASSUMING ASC c1

         DELETE FROM del_t GROUP BY c1
         HAVING COUNT(c2) > 4 AND any(c3 > 2)

        <q>.aq.c1:{upd_t}; .aq.c2:{del_t};</q>
      """
    val qcode =
      """
        .kdb.c1:{update c1:c1 * 2, c3:?[c3 > 50;1;-1] from `c1 xasc base};
        .kdb.c2:{delete from base where ({(any bi[`c3]>2)&4<count bi:base[x]};i) fby c1}
      """

    val tests = "c1,c2"
    val (passed0, msg0) = run(acode, qcode, tests, optimize = false)
    assert(passed0, "basic: " + msg0)

    val (passed1, msg1) = run(acode, qcode, tests, optimize = true)
    assert(passed1, "optimized: " + msg1)
  }

  test("simple.a") {
    val acode = getCode("simple.a")
    val qcode = getCode("q/simple.q")

    val tests = "q0,q1,q2,q3,q4,q5,q6,q7,q8,q9"
    val (passed0, msg0) = run(acode, qcode, tests, optimize = false)
    assert(passed0, msg0)

    val (passed1, msg1) = run(acode, qcode, tests, optimize = true)
    assert(passed1, msg1)
  }

  test("fintime.a") {
    // need a bit more work here to get path to data
    val load = getCode("q/load_fintime.q")
    val dataPath = getClass.getResource("data/").getFile
    val fullLoad = s"""<q>\nDATAPATH:"$dataPath";\n$load\n</q>"""
    // extend aquery code with data loading
    val acode = fullLoad + "\n" + getCode("fintime.a")
    val qcode = getCode("q/fintime.q")

    val tests = "q0,q1,q2,q3,q4,q5,q6,q7,q8,q9"
    val (passed0, msg0) = run(acode, qcode, tests, optimize = false)
    assert(passed0, msg0)

    val (passed1, msg1) = run(acode, qcode, tests, optimize = true)
    assert(passed1, msg1)
  }

  test("monetdb.a") {
    val acode = getCode("monetdb.a")
    val qcode = getCode("q/monetdb.q")

    val tests = "q0,q1"
    val (passed0, msg0) = run(acode, qcode, tests, optimize = false)
    assert(passed0, "basic: "  + msg0)

    val (passed1, msg1) = run(acode, qcode, tests, optimize = true)
    assert(passed1, "optimized: " + msg1)
  }

  test("pandas.a") {
    val acode = getCode("pandas.a")
    val qcode = getCode("q/pandas.q")

    val tests = "q0,q1,q2,q3,q4,q5,q6"
    val (passed0, msg0) = run(acode, qcode, tests, optimize = false)
    assert(passed0, "basic: "  + msg0)

    val (passed1, msg1) = run(acode, qcode, tests, optimize = true)
    assert(passed1, "optimized: " + msg1)
  }
}
