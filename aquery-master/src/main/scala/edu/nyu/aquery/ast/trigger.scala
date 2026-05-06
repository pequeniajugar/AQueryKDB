package edu.nyu.aquery.ast

sealed trait TriggerTime
case object Before extends TriggerTime
case object After extends TriggerTime

sealed trait TriggerEvent
case object InsertEvent extends TriggerEvent
case object UpdateEvent extends TriggerEvent
case object DeleteEvent extends TriggerEvent

sealed trait TriggerRefKind
case object NewTableRef extends TriggerRefKind
case object OldTableRef extends TriggerRefKind

case class TriggerRef(kind: TriggerRefKind, alias: String)

case class Trigger(
  name: String,
  time: TriggerTime,
  event: TriggerEvent,
  table: String,
  refs: List[TriggerRef],
  body: TopLevel) extends AST[Trigger] with TopLevel {

  def dotify(currAvail: Int) = {
    val label = s"trigger $name on $table"
    (Dot.declareNode(currAvail, label), currAvail + 1)
  }

  def transform(f: PartialFunction[Trigger, Trigger]) = transform0(f)
}

case class DropTrigger(name: String) extends AST[DropTrigger] with TopLevel {
  def dotify(currAvail: Int) = {
    val label = s"drop trigger $name"
    (Dot.declareNode(currAvail, label), currAvail + 1)
  }

  def transform(f: PartialFunction[DropTrigger, DropTrigger]) = transform0(f)
}
